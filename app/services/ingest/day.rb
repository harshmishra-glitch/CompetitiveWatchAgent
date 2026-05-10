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
        review_scrapes: 0, reviews: 0, reviews_skipped_no_match: 0
      }

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
        restaurants_by_slug: restaurants_by_slug,
        scrapped_at:         scrapped_at,
        scrapped_at_date:    scrapped_at_date
      )
      stats[:review_scrapes]           = rev_stats[:review_scrapes]
      stats[:reviews]                  = rev_stats[:reviews]
      stats[:reviews_skipped_no_match] = rev_stats[:skipped_no_match]

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

    def info_files
      dir = menus_subdir
      return [] unless dir
      Dir.glob(File.join(dir, "*_info.csv")).sort
    end

    def restaurants_by_slug
      Restaurant.all.each_with_object({}) do |r, h|
        slug = Ingest::Parsers.slug(r.name)
        h[slug] = r unless slug.empty?
      end
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
