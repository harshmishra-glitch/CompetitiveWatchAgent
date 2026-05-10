module Ingest
  class ReviewsLoader
    def self.load(restaurant:, review_csv_path:, scrapped_at:, scrapped_at_date:)
      return [] unless File.exist?(review_csv_path)

      attrs_list = []
      CSV.foreach(review_csv_path, headers: true) do |csv|
        next if Parsers.presence(csv["review_id"]).nil?
        attrs_list << build_attrs(csv, restaurant: restaurant,
                                       scrapped_at: scrapped_at,
                                       scrapped_at_date: scrapped_at_date)
      end
      return [] if attrs_list.empty?

      attrs_list.each_slice(500) do |slice|
        RestaurantGoogleReview.upsert_all(
          slice,
          unique_by: :index_reviews_on_review_id_and_scrape_date
        )
      end
      attrs_list
    end

    def self.build_attrs(row, restaurant:, scrapped_at:, scrapped_at_date:)
      raw_date = Parsers.presence(row["date"])
      now = Time.current
      {
        restaurant_id:     restaurant.id,
        restaurant_name:   restaurant.name,
        review_id:         row["review_id"].to_s.strip,
        place_name:        Parsers.presence(row["place_name"]),
        reviewer_name:     Parsers.presence(row["reviewer_name"]),
        reviewer_id:       Parsers.presence(row["reviewer_id"]),
        local_guide:       Parsers.boolean(row["local_guide"]),
        rating:            Parsers.integer(row["rating"]),
        review_text:       Parsers.presence(row["review_text"]),
        likes:             Parsers.integer(row["likes"]) || 0,
        date_raw:          raw_date,
        review_posted_at:  Parsers.relative_date(raw_date, reference: scrapped_at),
        review_attributes: Parsers.review_attributes(row["attributes"]),
        scrapped_at:       scrapped_at,
        scrapped_at_date:  scrapped_at_date,
        created_at:        now,
        updated_at:        now
      }
    end
  end
end
