module Competitors
  # Ranks restaurants as competitor candidates for a pilot, by:
  #   proximity (lat/lng) + cuisine overlap + price-band similarity + review volume.
  # Cheap heuristic — not learned. Returns enriched hashes with a `suggestion_score`.
  class Suggester
    DEFAULT_LIMIT      = 12
    PROXIMITY_RADIUS_KM = 5.0

    def self.call(pilot_restaurant:, limit: DEFAULT_LIMIT)
      new(pilot_restaurant: pilot_restaurant, limit: limit).call
    end

    def initialize(pilot_restaurant:, limit:)
      @pilot      = pilot_restaurant.restaurant
      @limit      = limit
      @pilot_snap = latest_snapshot(@pilot)
    end

    def call
      candidates = Restaurant.where.not(id: @pilot.id)
      candidates.find_each.filter_map { |r| score_for(r) }
                .sort_by { |row| -row[:suggestion_score] }
                .first(@limit)
    end

    private

    def score_for(restaurant)
      snap = latest_snapshot(restaurant)

      distance = haversine_km(@pilot.lat, @pilot.lng, restaurant.lat, restaurant.lng)
      cuisines = Array(restaurant.primary_cuisines).presence || Array(snap&.cuisines)
      cuisine_overlap = cuisine_overlap_score(cuisines)
      price_overlap   = price_band_score(restaurant, snap)
      volume          = (restaurant.review_count || 0).to_f
      volume_score    = Math.log10(volume + 1) / 5.0   # ~0..1 for 0..100k reviews

      proximity_score =
        if distance.nil?
          0.0
        else
          [1.0 - (distance / PROXIMITY_RADIUS_KM), 0.0].max
        end

      total = (proximity_score * 0.45) +
              (cuisine_overlap * 0.30) +
              (price_overlap   * 0.15) +
              (volume_score    * 0.10)

      {
        restaurant_id:      restaurant.id,
        name:               restaurant.name,
        locality:           snap&.locality,
        area:               snap&.area,
        distance_km:        distance&.round(2),
        primary_cuisines:   cuisines,
        avg_rating:         restaurant.rating,
        review_count:       restaurant.review_count,
        cost_for_two:       restaurant.cost_for_two || snap&.cost_for_two,
        image_url:          snap&.image_url,
        suggestion_score:   total.round(4)
      }
    end

    def latest_snapshot(restaurant)
      restaurant.scrapes.order(scrapped_at_date: :desc).first
    end

    def cuisine_overlap_score(other_cuisines)
      pilot_cuisines = (Array(@pilot.primary_cuisines).presence || Array(@pilot_snap&.cuisines)).map(&:downcase)
      others = other_cuisines.map(&:downcase)
      return 0.0 if pilot_cuisines.empty? || others.empty?
      intersection = (pilot_cuisines & others).size
      union        = (pilot_cuisines | others).size
      union.zero? ? 0.0 : intersection.to_f / union
    end

    def price_band_score(other, other_snap)
      pilot_cost = @pilot.cost_for_two || @pilot_snap&.cost_for_two
      other_cost = other.cost_for_two || other_snap&.cost_for_two
      return 0.0 if pilot_cost.nil? || other_cost.nil? || pilot_cost.zero?
      diff_ratio = (pilot_cost - other_cost).abs.to_f / pilot_cost
      [1.0 - diff_ratio, 0.0].max
    end

    def haversine_km(lat1, lng1, lat2, lng2)
      return nil if [lat1, lng1, lat2, lng2].any?(&:nil?)
      r = 6371.0
      to_rad = ->(d) { d.to_f * Math::PI / 180 }
      d_lat = to_rad.call(lat2 - lat1)
      d_lng = to_rad.call(lng2 - lng1)
      a = Math.sin(d_lat / 2)**2 +
          Math.cos(to_rad.call(lat1)) * Math.cos(to_rad.call(lat2)) *
          Math.sin(d_lng / 2)**2
      r * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    end
  end
end
