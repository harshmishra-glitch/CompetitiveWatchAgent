require "json"

module Ingest
  class GoogleSerpLoader
    SERP_FILENAME_RE = /\A(.+?)_(\d{8})_(\d{6})\z/.freeze

    def self.load(scrapes_dir:, restaurants_by_slug:, scrapped_at:, scrapped_at_date:)
      stats = { serp_scrapes: 0, serp_results: 0, serp_questions: 0, skipped_no_match: 0 }
      return stats unless Dir.exist?(scrapes_dir)

      Dir.glob(File.join(scrapes_dir, "*.json")).sort.each do |path|
        base       = File.basename(path, ".json")
        name_part  = base.match(SERP_FILENAME_RE)&.[](1) || base
        slug       = Parsers.slug(name_part)
        restaurant = restaurants_by_slug[slug]

        if restaurant.nil?
          stats[:skipped_no_match] += 1
          warn "[serp] no Restaurant for slug=#{slug.inspect} (#{File.basename(path)})"
          next
        end

        payload = parse_json(path)
        next if payload.nil?

        first = payload.is_a?(Array) ? payload.first : payload
        next if first.nil?

        scrape = GoogleSerpScrape
                   .where(restaurant_id: restaurant.id, scrapped_at_date: scrapped_at_date)
                   .first_or_initialize
        scrape.update!(
          search_term:      first.dig("searchQuery", "term"),
          search_url:       Parsers.presence(first["url"]),
          results_total:    Parsers.integer(first["resultsTotal"]),
          has_next_page:    first["hasNextPage"] == true,
          provider_code:    Parsers.presence(first["serpProviderCode"]),
          payload:          payload,
          scrapped_at:      scrapped_at,
          scrapped_at_date: scrapped_at_date
        )

        result_rows = []
        Array(first["organicResults"]).each do |row|
          result_rows << build_result_row(row, "organic", scrape, restaurant, scrapped_at_date)
        end
        Array(first["paidResults"]).each do |row|
          result_rows << build_result_row(row, "paid", scrape, restaurant, scrapped_at_date)
        end
        result_rows.compact!

        question_rows = Array(first["peopleAlsoAsk"]).filter_map do |q|
          build_question_row(q, scrape, restaurant, scrapped_at_date)
        end

        SerpOrganicResult.where(google_serp_scrape_id: scrape.id).delete_all
        SerpQuestion.where(google_serp_scrape_id: scrape.id).delete_all

        result_rows.each_slice(500)   { |slice| SerpOrganicResult.insert_all!(slice) }
        question_rows.each_slice(500) { |slice| SerpQuestion.insert_all!(slice) }

        stats[:serp_scrapes]   += 1
        stats[:serp_results]   += result_rows.size
        stats[:serp_questions] += question_rows.size
      end

      stats
    end

    def self.parse_json(path)
      JSON.parse(File.read(path))
    rescue JSON::ParserError => e
      warn "[serp] cannot parse #{File.basename(path)}: #{e.message}"
      nil
    end

    def self.build_result_row(row, default_type, scrape, restaurant, scrapped_at_date)
      title = Parsers.presence(row["title"])
      url   = Parsers.presence(row["url"])
      return nil if title.nil? && url.nil?

      now = Time.current
      {
        google_serp_scrape_id: scrape.id,
        restaurant_id:         restaurant.id,
        position:              Parsers.integer(row["position"]),
        result_type:           Parsers.presence(row["type"]) || default_type,
        title:                 title,
        url:                   url,
        displayed_url:         Parsers.presence(row["displayedUrl"]),
        description:           Parsers.presence(row["description"]),
        channel_name:          Parsers.presence(row["channelName"]),
        average_rating:        Parsers.decimal(row["averageRating"]),
        number_of_reviews:     Parsers.integer(row["numberOfReviews"]),
        followers_amount:      Parsers.presence(row["followersAmount"]),
        views:                 Parsers.presence(row["views"]),
        last_updated_raw:      Parsers.presence(row["lastUpdated"]),
        emphasized_keywords:   Array(row["emphasizedKeywords"]),
        site_links:            row["siteLinks"],
        product_info:          row["productInfo"],
        raw:                   row,
        scrapped_at_date:      scrapped_at_date,
        created_at:            now,
        updated_at:            now
      }
    end

    def self.build_question_row(q, scrape, restaurant, scrapped_at_date)
      question = Parsers.presence(q["question"])
      return nil if question.nil?

      now = Time.current
      {
        google_serp_scrape_id: scrape.id,
        restaurant_id:         restaurant.id,
        question:              question,
        answer:                Parsers.presence(q["answer"]),
        title:                 Parsers.presence(q["title"]),
        url:                   Parsers.presence(q["url"]),
        date_raw:              Parsers.presence(q["date"]),
        scrapped_at_date:      scrapped_at_date,
        created_at:            now,
        updated_at:            now
      }
    end
  end
end
