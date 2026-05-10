require "csv"

module Ingest
  class Day
    MONTHS = {
      "Jan" => 1, "Feb" => 2, "Mar" => 3, "Apr" => 4, "May" => 5, "Jun" => 6,
      "Jul" => 7, "Aug" => 8, "Sep" => 9, "Oct" => 10, "Nov" => 11, "Dec" => 12
    }.freeze

    attr_reader :folder, :scrapped_at, :scrapped_at_date

    def self.scrape_date_for(folder_name, year:)
      m = folder_name.match(/Data_(\d+)(#{MONTHS.keys.join('|')})/i)
      raise ArgumentError, "Cannot parse date from #{folder_name}" unless m
      Date.new(year, MONTHS[m[2].capitalize], m[1].to_i)
    end

    def initialize(folder:, year: Date.current.year)
      @folder           = folder
      @scrapped_at_date = self.class.scrape_date_for(File.basename(folder), year: year)
      @scrapped_at      = Time.zone.local(@scrapped_at_date.year,
                                          @scrapped_at_date.month,
                                          @scrapped_at_date.day, 23, 59, 59)
    end

    def call
      stats = {
        scrapes: 0, menu_items: 0, skipped_no_match: 0,
        review_scrapes: 0, reviews: 0, reviews_skipped_no_match: 0,
        ig_scrapes: 0, ig_posts: 0, ig_skipped_no_match: 0,
        serp_scrapes: 0, serp_results: 0, serp_questions: 0, serp_skipped_no_match: 0
      }

      slug_map = restaurants_by_slug

      info_files.each do |info_path|
        row = CSV.read(info_path, headers: true).first
        next if row.nil?

        scrape = Ingest::RestaurantRecord.upsert_scrape(
          row,
          scrapped_at:      scrapped_at,
          scrapped_at_date: scrapped_at_date
        )

        if scrape.nil?
          stats[:skipped_no_match] += 1
          warn "[#{File.basename(folder)}] no Restaurant for input_name=#{row['input_name'].inspect} (#{File.basename(info_path)})"
          next
        end

        stats[:scrapes] += 1

        menu_path = info_path.sub(/_info\.csv\z/, ".csv")
        menu_rows = Ingest::MenuLoader.load(scrape: scrape, menu_csv_path: menu_path)
        stats[:menu_items] += menu_rows.size
        backfill_menu_jsonb(scrape, menu_rows)
      end

      rev_stats = Ingest::GoogleReviewsLoader.load(
        reviews_dir:         reviews_subdir,
        restaurants_by_slug: slug_map,
        scrapped_at:         scrapped_at,
        scrapped_at_date:    scrapped_at_date
      )
      stats[:review_scrapes]           = rev_stats[:review_scrapes]
      stats[:reviews]                  = rev_stats[:reviews]
      stats[:reviews_skipped_no_match] = rev_stats[:skipped_no_match]

      ig_stats = Ingest::InstagramLoader.load(
        scrapes_dir:         instagram_subdir,
        restaurants_by_slug: slug_map,
        scrapped_at:         scrapped_at,
        scrapped_at_date:    scrapped_at_date
      )
      stats[:ig_scrapes]          = ig_stats[:ig_scrapes]
      stats[:ig_posts]            = ig_stats[:ig_posts]
      stats[:ig_skipped_no_match] = ig_stats[:skipped_no_match]

      serp_stats = Ingest::GoogleSerpLoader.load(
        scrapes_dir:         serp_subdir,
        restaurants_by_slug: slug_map,
        scrapped_at:         scrapped_at,
        scrapped_at_date:    scrapped_at_date
      )
      stats[:serp_scrapes]          = serp_stats[:serp_scrapes]
      stats[:serp_results]          = serp_stats[:serp_results]
      stats[:serp_questions]        = serp_stats[:serp_questions]
      stats[:serp_skipped_no_match] = serp_stats[:skipped_no_match]

      stats
    end

    private

    def menus_subdir
      %w[restaurantsAndMenus restaurantAndMenus].map { |d| File.join(folder, d) }
                                                .find { |p| Dir.exist?(p) }
    end

    def reviews_subdir
      File.join(folder, "googleReviews")
    end

    def instagram_subdir
      File.join(folder, "instagramScrapes")
    end

    def serp_subdir
      File.join(folder, "googleSerpScrapes")
    end

    def info_files
      dir = menus_subdir
      return [] unless dir
      Dir.glob(File.join(dir, "*_info.csv")).sort
    end

    def restaurants_by_slug
      ordered = Restaurant.order(Arel.sql("review_count DESC NULLS LAST")).to_a
      map = {}

      ordered.each do |r|
        slug = Ingest::Parsers.slug(r.name)
        map[slug] = r unless slug.empty?
      end

      # Brand-level alias: a file named after the parent brand
      # (e.g. "Blue_Tokai_Coffee_Roasters.json") falls back to the
      # flagship outlet (highest review_count) of that brand.
      ordered.each do |r|
        brand = Ingest::Parsers.brand_slug(r.name)
        next if brand.empty?
        map[brand] ||= r
      end

      map
    end

    def backfill_menu_jsonb(scrape, rows)
      return if rows.empty?
      payload = rows.map do |r|
        r.slice(:category, :subcategory, :name, :price_raw, :price, :variants,
                :description, :veg, :rating, :rating_count, :bestseller, :availability)
         .transform_keys(&:to_s)
      end
      scrape.update_columns(menu: payload, updated_at: Time.current)
    end
  end
end
