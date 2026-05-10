module Reviews
  # Backfills `restaurants_scrapped.google_rating` and `.google_rating_count`
  # when Swiggy's *_info.csv didn't carry them (the "--" case).
  #
  # Strategy: weighted blend of the seed and the scraped recent reviews.
  #   - seed:    restaurants.rating + restaurants.review_count
  #              (the headline Google rating from the seed CSV — large N)
  #   - scraped: per-review ratings inside google_review_scrapes.reviews
  #              (small N but fresh)
  #
  #   blended_rating = (seed.rating * seed.count + sum(scraped.ratings)) /
  #                    (seed.count + scraped.count)
  #
  # Only fills rows where google_rating is NULL — we don't overwrite Swiggy-
  # supplied values.
  class GoogleRatingBackfiller
    def self.call(restaurant_id: nil)
      new(restaurant_id: restaurant_id).call
    end

    def initialize(restaurant_id: nil)
      @restaurant_id = restaurant_id
    end

    def call
      stats = { checked: 0, updated: 0, skipped_no_seed: 0, skipped_already_set: 0 }
      snaps = base_scope.includes(:restaurant)
      snaps.find_each do |snap|
        stats[:checked] += 1
        if snap.google_rating.present? && snap.google_rating_count.present?
          stats[:skipped_already_set] += 1
          next
        end

        result = blend(snap)
        if result.nil?
          stats[:skipped_no_seed] += 1
          next
        end

        snap.update_columns(
          google_rating:       result[:rating],
          google_rating_count: result[:count]
        )
        stats[:updated] += 1
      end
      stats
    end

    private

    def base_scope
      scope = RestaurantsScrapped.all
      scope = scope.where(restaurant_id: @restaurant_id) if @restaurant_id
      scope
    end

    def blend(snap)
      seed         = snap.restaurant
      seed_count   = (seed.review_count || 0).to_i
      seed_rating  = seed.rating.to_f

      scraped      = scraped_ratings_for(snap.restaurant_id, snap.scrapped_at_date)
      scraped_n    = scraped.size
      scraped_sum  = scraped.sum.to_f

      total_count = seed_count + scraped_n
      return nil if total_count.zero?

      total_sum = (seed_rating * seed_count) + scraped_sum
      avg       = (total_sum / total_count).round(2)
      { rating: avg, count: total_count }
    end

    def scraped_ratings_for(restaurant_id, date)
      grs = GoogleReviewScrape.find_by(restaurant_id: restaurant_id, scrapped_at_date: date)
      return [] if grs.nil?
      Array(grs.reviews).map { |r| r["rating"] }.compact
    end
  end
end
