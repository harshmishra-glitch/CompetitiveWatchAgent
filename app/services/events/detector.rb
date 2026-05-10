module Events
  # Diffs yesterday vs today for one restaurant and writes the changes to
  #   - menu_change_events            (one row per item add/remove/reprice)
  #   - competitor_activity_events    (unified feed: menu + rating + offers + social)
  #
  # Idempotent for a given (restaurant_id, date): deletes today's rows for that
  # restaurant before re-inserting so reruns produce the same final state.
  #
  # Pure Ruby — no LLM. Called by:
  #   - rake events:detect / events:backfill
  #   - the daily orchestrator before digests run
  class Detector
    RATING_SHIFT_THRESHOLD = 0.1   # avg_rating delta worth recording
    PRICE_DELTA_MIN        = 1     # ignore zero-rupee "changes"

    def self.persist_for(restaurant_id:, date:)
      new(restaurant_id: restaurant_id, date: date).call
    end

    def self.persist_range(restaurant_ids:, from:, to:)
      counts = Hash.new(0)
      restaurant_ids.each do |rid|
        (from..to).each do |d|
          c = persist_for(restaurant_id: rid, date: d)
          c.each { |k, v| counts[k] += v }
        end
      end
      counts
    end

    def initialize(restaurant_id:, date:)
      @restaurant_id = restaurant_id
      @date          = date
    end

    def call
      today, prev = last_two_scrapes
      return zero_counts if today.nil?

      ActiveRecord::Base.transaction do
        clear_today_rows
        menu_count   = persist_menu_events(today, prev)
        rating_count = persist_rating_shift(today, prev)
        offer_count  = persist_offer_changes(today, prev)
        social_count = persist_social_posts
        google_count = persist_google_review_events(today, prev)

        {
          menu_change_events:         menu_count,
          competitor_activity_events: menu_count + rating_count + offer_count + social_count + google_count
        }
      end
    end

    private

    def zero_counts
      { menu_change_events: 0, competitor_activity_events: 0 }
    end

    def last_two_scrapes
      scrapes = RestaurantsScrapped
                  .where(restaurant_id: @restaurant_id)
                  .where("scrapped_at_date <= ?", @date)
                  .order(scrapped_at_date: :desc)
                  .limit(2)
                  .to_a
      today = scrapes.first
      prev  = scrapes[1]
      # If today's row isn't actually on @date, treat it as missing.
      today = nil if today && today.scrapped_at_date != @date
      [today, prev]
    end

    def clear_today_rows
      MenuChangeEvent
        .where(restaurant_id: @restaurant_id, scrapped_at_date: @date)
        .delete_all
      CompetitorActivityEvent
        .where(restaurant_id: @restaurant_id, occurred_on: @date)
        .delete_all
    end

    # ---- menu_items diff ----

    def persist_menu_events(today, prev)
      return 0 if prev.nil?

      today_items = MenuItem.where(restaurants_scrapped_id: today.id).to_a
      prev_items  = MenuItem.where(restaurants_scrapped_id: prev.id).to_a

      today_by_name = today_items.index_by(&:name)
      prev_by_name  = prev_items.index_by(&:name)

      written = 0

      (today_by_name.keys - prev_by_name.keys).each do |name|
        i = today_by_name[name]
        mce = create_menu_change_event(
          event_type: "added", item: i, prev_price: nil, new_price: i.price, prev_name: nil, new_name: i.name,
          prev_date: prev.scrapped_at_date
        )
        create_activity_from_menu_change(mce,
          summary:      "Added #{i.name}#{" at ₹#{i.price}" if i.price}",
          significance: 2.0)
        written += 1
      end

      (prev_by_name.keys - today_by_name.keys).each do |name|
        i = prev_by_name[name]
        mce = create_menu_change_event(
          event_type: "removed", item: i, prev_price: i.price, new_price: nil, prev_name: i.name, new_name: nil,
          prev_date: prev.scrapped_at_date
        )
        create_activity_from_menu_change(mce,
          summary:      "Removed #{i.name}",
          significance: 1.5)
        written += 1
      end

      (today_by_name.keys & prev_by_name.keys).each do |name|
        a = today_by_name[name]
        b = prev_by_name[name]
        next if a.price.nil? || b.price.nil?
        delta = a.price - b.price
        next if delta.abs < PRICE_DELTA_MIN

        type = delta.positive? ? "price_increased" : "price_decreased"
        mce = create_menu_change_event(
          event_type: type, item: a, prev_price: b.price, new_price: a.price, prev_name: nil, new_name: nil,
          prev_date: prev.scrapped_at_date
        )
        sig = ((delta.abs.to_f / [b.price, 1].max) * 5).clamp(0.5, 10.0)
        create_activity_from_menu_change(mce,
          summary:      "#{name}: ₹#{b.price} → ₹#{a.price}",
          significance: sig)
        written += 1
      end

      written
    end

    def create_menu_change_event(event_type:, item:, prev_price:, new_price:, prev_name:, new_name:, prev_date:)
      MenuChangeEvent.create!(
        restaurant_id:         @restaurant_id,
        event_type:            event_type,
        menu_item_name:        item.name,
        category:              item.category,
        subcategory:           item.subcategory,
        prev_price:            prev_price,
        new_price:             new_price,
        price_delta:           (prev_price && new_price ? new_price - prev_price : nil),
        prev_name:             prev_name,
        new_name:              new_name,
        prev_scrapped_at_date: prev_date,
        scrapped_at_date:      @date,
        before:                prev_price && { name: item.name, price: prev_price },
        after:                 new_price  && { name: item.name, price: new_price }
      )
    end

    def create_activity_from_menu_change(mce, summary:, significance:)
      CompetitorActivityEvent.create!(
        restaurant_id:        @restaurant_id,
        event_type:           "menu_#{mce.event_type}",
        summary:              summary,
        detected_from:        "menu_change_events",
        source_record_id:     mce.id,
        menu_change_event_id: mce.id,
        before:               mce.before,
        after:                mce.after,
        significance:         significance,
        occurred_on:          @date,
        detected_at:          Time.current
      )
    end

    # ---- rating_shift ----

    def persist_rating_shift(today, prev)
      return 0 if prev.nil? || today.avg_rating.nil? || prev.avg_rating.nil?
      delta = (today.avg_rating - prev.avg_rating).to_f
      return 0 if delta.abs < RATING_SHIFT_THRESHOLD

      verb = delta.positive? ? "rose" : "dropped"
      CompetitorActivityEvent.create!(
        restaurant_id: @restaurant_id,
        event_type:    "rating_shift",
        summary:       "Rating #{verb} #{delta.abs.round(2)} (#{prev.avg_rating} → #{today.avg_rating})",
        detected_from: "restaurants_scrapped",
        source_record_id: today.id,
        before:        { avg_rating: prev.avg_rating.to_f },
        after:         { avg_rating: today.avg_rating.to_f },
        significance:  (delta.abs * 10).clamp(0, 10),
        occurred_on:   @date,
        detected_at:   Time.current
      )
      1
    end

    # ---- offers add/remove ----

    def persist_offer_changes(today, prev)
      return 0 if prev.nil?
      added   = Array(today.offers) - Array(prev.offers)
      removed = Array(prev.offers)  - Array(today.offers)
      return 0 if added.empty? && removed.empty?

      now = Time.current
      written = 0

      added.each do |o|
        CompetitorActivityEvent.create!(
          restaurant_id: @restaurant_id, event_type: "offer_added",
          summary: "New offer: #{o}", detected_from: "restaurants_scrapped",
          source_record_id: today.id,
          before: nil, after: { offer: o },
          significance: 3.0, occurred_on: @date, detected_at: now
        )
        written += 1
      end

      removed.each do |o|
        CompetitorActivityEvent.create!(
          restaurant_id: @restaurant_id, event_type: "offer_removed",
          summary: "Dropped offer: #{o}", detected_from: "restaurants_scrapped",
          source_record_id: today.id,
          before: { offer: o }, after: nil,
          significance: 1.5, occurred_on: @date, detected_at: now
        )
        written += 1
      end

      written
    end

    # ---- Google reviews ----

    def persist_google_review_events(today_snap, prev_snap)
      persist_google_review_new +
        persist_google_rating_shift(today_snap, prev_snap) +
        persist_google_review_surge(today_snap, prev_snap)
    end

    def persist_google_review_new
      today_grs = GoogleReviewScrape.find_by(restaurant_id: @restaurant_id, scrapped_at_date: @date)
      return 0 if today_grs.nil?

      prev_grs = GoogleReviewScrape
                   .where(restaurant_id: @restaurant_id)
                   .where("scrapped_at_date < ?", @date)
                   .order(scrapped_at_date: :desc)
                   .first
      return 0 if prev_grs.nil?   # skip first scrape — no baseline to diff against

      prev_ids = Array(prev_grs.reviews).map { |r| r["review_id"] }.compact.to_set
      new_reviews = Array(today_grs.reviews).reject { |r|
        r["review_id"].nil? || prev_ids.include?(r["review_id"])
      }
      return 0 if new_reviews.empty?

      now = Time.current
      new_reviews.each { |r| create_google_review_new_event(r, today_grs, now) }
      new_reviews.size
    end

    def create_google_review_new_event(review, today_grs, now)
      rating = review["rating"].to_i
      significance = case rating
                     when 0..2 then 4.0      # negative review — loudest signal
                     when 3    then 2.0      # neutral
                     else           1.0      # 4-5★ — quieter
                     end
      text_preview = review["review_text"].to_s
      text_preview = "(no text)" if text_preview.strip.empty?
      summary = "#{rating}★ from #{review["reviewer_name"]}: #{text_preview.truncate(120)}"

      CompetitorActivityEvent.create!(
        restaurant_id:        @restaurant_id,
        event_type:           "google_review_new",
        summary:              summary,
        detected_from:        "google_review_scrapes",
        source_record_id:     today_grs.id,
        before:               nil,
        after: {
          review_id: review["review_id"],
          reviewer:  review["reviewer_name"],
          rating:    rating,
          text:      review["review_text"]&.then { |t| t.length > 240 ? t[0, 237] + "..." : t },
          date_raw:  review["date_raw"]
        },
        significance: significance,
        occurred_on:  @date,
        detected_at:  now
      )
    end

    def persist_google_rating_shift(today_snap, prev_snap)
      return 0 if today_snap.nil? || prev_snap.nil?
      return 0 if today_snap.google_rating.nil? || prev_snap.google_rating.nil?
      delta = (today_snap.google_rating - prev_snap.google_rating).to_f
      return 0 if delta.abs < RATING_SHIFT_THRESHOLD

      verb = delta.positive? ? "rose" : "dropped"
      CompetitorActivityEvent.create!(
        restaurant_id:    @restaurant_id,
        event_type:       "google_rating_shift",
        summary:          "Google rating #{verb} #{delta.abs.round(2)} (#{prev_snap.google_rating} → #{today_snap.google_rating})",
        detected_from:    "restaurants_scrapped",
        source_record_id: today_snap.id,
        before:           { google_rating: prev_snap.google_rating.to_f },
        after:            { google_rating: today_snap.google_rating.to_f },
        significance:     (delta.abs * 10).clamp(0, 10),
        occurred_on:      @date,
        detected_at:      Time.current
      )
      1
    end

    def persist_google_review_surge(today_snap, prev_snap)
      return 0 if today_snap.nil? || prev_snap.nil?
      return 0 if today_snap.google_rating_count.nil? || prev_snap.google_rating_count.nil?

      delta = today_snap.google_rating_count - prev_snap.google_rating_count
      return 0 if delta <= 0

      median = median_daily_review_growth
      return 0 if median <= 0 || delta < (2 * median)

      CompetitorActivityEvent.create!(
        restaurant_id:    @restaurant_id,
        event_type:       "google_review_surge",
        summary:          "Google review volume up #{delta} in a day (median: #{median})",
        detected_from:    "restaurants_scrapped",
        source_record_id: today_snap.id,
        before:           { count: prev_snap.google_rating_count },
        after:            { count: today_snap.google_rating_count },
        significance:     (delta.to_f / median).clamp(0, 10),
        occurred_on:      @date,
        detected_at:      Time.current
      )
      1
    end

    def median_daily_review_growth
      history = RestaurantsScrapped
                  .where(restaurant_id: @restaurant_id)
                  .where(scrapped_at_date: (@date - 7.days)..@date)
                  .order(:scrapped_at_date)
                  .pluck(:google_rating_count)
                  .compact
      return 0 if history.size < 3
      daily_growth = history.each_cons(2).map { |a, b| (b - a).clamp(0, Float::INFINITY) }
      sorted = daily_growth.sort
      sorted[sorted.size / 2].to_i
    end

    # ---- social posts (own-brand profile posts on @date) ----

    def persist_social_posts
      posts = InstagramPost
                .where(restaurant_id: @restaurant_id, source: "profile", scrapped_at_date: @date)
                .order(engagement_score: :desc)
                .limit(5)

      now = Time.current
      written = 0
      posts.each do |p|
        promo = p.is_promotional
        CompetitorActivityEvent.create!(
          restaurant_id: @restaurant_id,
          event_type:    promo ? "social_post_promo" : "social_post",
          summary:       (promo ? "Promo post: " : "New post: ") +
                         (p.caption.to_s.truncate(120).presence || "(no caption)"),
          detected_from: "instagram_posts",
          source_record_id: p.id,
          before: nil,
          after:  { post_url: p.post_url, likes: p.likes_count, hashtags: p.hashtags,
                    sentiment: p.caption_sentiment, engagement_score: p.engagement_score },
          significance: promo ? 3.0 : 1.0,
          occurred_on:  @date,
          detected_at:  now
        )
        written += 1
      end
      written
    end
  end
end
