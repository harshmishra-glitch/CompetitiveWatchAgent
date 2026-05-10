module Ingest
  class RestaurantRecord
    def self.upsert_scrape(row, scrapped_at:, scrapped_at_date:)
      input_name = Parsers.presence(row["input_name"])
      return nil if input_name.nil?

      restaurant = Restaurant.find_by(name: input_name)
      return nil if restaurant.nil?

      attrs = {
        restaurant_id:        restaurant.id,
        swiggy_restaurant_id: Parsers.integer(row["restaurant_id"]),
        input_name:           input_name,
        name:                 Parsers.presence(row["name"]) || input_name,
        city:                 Parsers.presence(row["city"]),
        locality:             Parsers.presence(row["locality"]),
        area:                 Parsers.presence(row["area"]),
        address:              Parsers.presence(row["address"]),
        cost_for_two_raw:     Parsers.presence(row["cost_for_two"]),
        cost_for_two:         Parsers.cost_for_two(row["cost_for_two"]),
        cuisines:             Parsers.cuisines(row["cuisines"]),
        avg_rating:           Parsers.decimal(row["avg_rating"]),
        total_ratings_raw:    Parsers.presence(row["total_ratings"]),
        total_ratings:        Parsers.total_ratings(row["total_ratings"]),
        google_rating:        Parsers.decimal(row["google_rating"]),
        google_rating_count:  Parsers.integer(row["google_rating_count"]),
        pure_veg:             Parsers.boolean(row["pure_veg"]),
        is_open:              Parsers.boolean(row["is_open"]),
        next_close_time:      Parsers.datetime(row["next_close_time"]),
        delivery_time_min:    Parsers.integer(row["delivery_time_min"]),
        delivery_time_max:    Parsers.integer(row["delivery_time_max"]),
        distance_km:          Parsers.decimal(row["distance_km"]),
        parent_id:            Parsers.integer(row["parent_id"]),
        is_chain:             Parsers.boolean(row["is_chain"]),
        discount_header:      Parsers.presence(row["discount_header"]),
        offers:               Parsers.offers(row["offers"]),
        image_url:            Parsers.presence(row["image_url"]),
        swiggy_url:           Parsers.presence(row["swiggy_url"]),
        swiggy_lat:           Parsers.decimal(row["swiggy_lat"]),
        swiggy_lng:           Parsers.decimal(row["swiggy_lng"]),
        scrapped_at:          scrapped_at,
        scrapped_at_date:     scrapped_at_date
      }

      RestaurantsScrapped
        .where(restaurant_id: restaurant.id, scrapped_at_date: scrapped_at_date)
        .first_or_initialize
        .tap { |s| s.update!(attrs) }
    end
  end
end
