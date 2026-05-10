require "csv"
require "json"

module Ingest
  class GoogleReviewsLoader
    def self.load(reviews_dir:, restaurants_by_slug:, scrapped_at:, scrapped_at_date:)
      stats = { review_scrapes: 0, reviews: 0, skipped_no_match: 0 }
      return stats unless Dir.exist?(reviews_dir)

      Dir.glob(File.join(reviews_dir, "*.csv")).sort.each do |path|
        slug       = File.basename(path, ".csv")
        restaurant = restaurants_by_slug[slug]

        if restaurant.nil?
          stats[:skipped_no_match] += 1
          warn "[reviews] no Restaurant for slug=#{slug.inspect} (#{File.basename(path)})"
          next
        end

        rows = CSV.read(path, headers: true).filter_map { |r| build_review_row(r) }
        next if rows.empty?

        scrape = GoogleReviewScrape
                   .where(restaurant_id: restaurant.id, scrapped_at_date: scrapped_at_date)
                   .first_or_initialize
        scrape.update!(
          reviews:          rows,
          review_count:     rows.size,
          scrapped_at:      scrapped_at,
          scrapped_at_date: scrapped_at_date
        )

        stats[:review_scrapes] += 1
        stats[:reviews] += rows.size
      end

      stats
    end

    def self.build_review_row(row)
      review_id = Parsers.presence(row["review_id"])
      return nil if review_id.nil?

      {
        "review_id"     => review_id,
        "place_name"    => Parsers.presence(row["place_name"]),
        "reviewer_name" => Parsers.presence(row["reviewer_name"]),
        "reviewer_id"   => Parsers.presence(row["reviewer_id"]),
        "local_guide"   => Parsers.boolean(row["local_guide"]),
        "rating"        => Parsers.integer(row["rating"]),
        "review_text"   => Parsers.presence(row["review_text"]),
        "likes"         => Parsers.integer(row["likes"]),
        "date_raw"      => Parsers.presence(row["date"]),
        "attributes"    => parse_attributes(row["attributes"])
      }
    end

    def self.parse_attributes(value)
      stripped = Parsers.presence(value)
      return nil if stripped.nil?
      JSON.parse(stripped)
    rescue JSON::ParserError
      nil
    end
  end
end
