module Digest
  # Builds a list of "what changed yesterday" events for one restaurant.
  # Reads from menu_change_events / competitor_activity_events when populated,
  # otherwise falls back to diffing the last two restaurants_scrapped snapshots
  # so the digest still works on day one.
  class EventCollector
    def self.for(restaurant_id:, on_date:)
      new(restaurant_id: restaurant_id, on_date: on_date).call
    end

    def initialize(restaurant_id:, on_date:)
      @restaurant_id = restaurant_id
      @on_date       = on_date
    end

    def call
      events = []
      events.concat(persisted_menu_changes)
      events.concat(persisted_activity_events)
      events.concat(rating_drift_events) if events.empty?
      events.concat(menu_diff_events)    if persisted_menu_changes.empty?
      events.concat(offer_change_events)
      events.concat(social_post_events)
      events.uniq { |e| [e[:event_type], e[:summary]] }
    end

    private

    def persisted_menu_changes
      @persisted_menu_changes ||= MenuChangeEvent
        .where(restaurant_id: @restaurant_id, scrapped_at_date: @on_date)
        .map { |e|
          {
            event_type:   "menu_#{e.event_type}",
            summary:      menu_change_summary(e),
            occurred_on:  e.scrapped_at_date,
            significance: significance_for_menu(e),
            source_id:    e.id,
            source_table: "menu_change_events",
            details:      menu_change_payload(e)
          }
        }
    end

    def persisted_activity_events
      CompetitorActivityEvent
        .where(restaurant_id: @restaurant_id, occurred_on: @on_date)
        .map { |e|
          {
            event_type:   e.event_type,
            summary:      e.summary || e.event_type.titleize,
            occurred_on:  e.occurred_on,
            significance: e.significance.to_f,
            source_id:    e.id,
            source_table: "competitor_activity_events",
            details:      { before: e.before, after: e.after }
          }
        }
    end

    def menu_diff_events
      today, yesterday = last_two_scrapes
      return [] if today.nil? || yesterday.nil?

      today_items     = MenuItem.where(restaurants_scrapped_id: today.id).index_by(&:name)
      yesterday_items = MenuItem.where(restaurants_scrapped_id: yesterday.id).index_by(&:name)

      added = (today_items.keys - yesterday_items.keys).map { |n|
        item = today_items[n]
        {
          event_type: "menu_added",
          summary:    "Added #{n}#{" at ₹#{item.price}" if item.price}",
          occurred_on: today.scrapped_at_date,
          significance: 2.0,
          details: { item: item.slice(:name, :category, :price) }
        }
      }
      removed = (yesterday_items.keys - today_items.keys).map { |n|
        item = yesterday_items[n]
        {
          event_type: "menu_removed",
          summary:    "Removed #{n}",
          occurred_on: today.scrapped_at_date,
          significance: 1.5,
          details: { item: item.slice(:name, :category, :price) }
        }
      }
      repriced = (today_items.keys & yesterday_items.keys).filter_map { |n|
        a = today_items[n]
        b = yesterday_items[n]
        next nil if a.price.nil? || b.price.nil? || a.price == b.price
        delta = a.price - b.price
        {
          event_type: delta.positive? ? "price_increased" : "price_decreased",
          summary:    "#{n}: ₹#{b.price} → ₹#{a.price}",
          occurred_on: today.scrapped_at_date,
          significance: (delta.abs / [b.price.to_f, 1].max) * 5,
          details: { name: n, prev_price: b.price, new_price: a.price, delta: delta }
        }
      }
      added + removed + repriced
    end

    def rating_drift_events
      today, yesterday = last_two_scrapes
      return [] if today.nil? || yesterday.nil?
      return [] if today.avg_rating.nil? || yesterday.avg_rating.nil?
      delta = (today.avg_rating - yesterday.avg_rating).to_f
      return [] if delta.abs < 0.05

      [{
        event_type: "rating_shift",
        summary:    "Rating #{delta.positive? ? 'rose' : 'dropped'} #{delta.abs.round(2)} (#{yesterday.avg_rating} → #{today.avg_rating})",
        occurred_on: today.scrapped_at_date,
        significance: (delta.abs * 10).clamp(0, 10),
        details: { prev: yesterday.avg_rating, new: today.avg_rating, delta: delta }
      }]
    end

    def offer_change_events
      today, yesterday = last_two_scrapes
      return [] if today.nil? || yesterday.nil?
      added = Array(today.offers) - Array(yesterday.offers)
      removed = Array(yesterday.offers) - Array(today.offers)

      events = []
      added.each do |o|
        events << { event_type: "offer_added", summary: "New offer: #{o}",
                    occurred_on: today.scrapped_at_date, significance: 3.0,
                    details: { offer: o } }
      end
      removed.each do |o|
        events << { event_type: "offer_removed", summary: "Dropped offer: #{o}",
                    occurred_on: today.scrapped_at_date, significance: 1.5,
                    details: { offer: o } }
      end
      events
    end

    def social_post_events
      posts = InstagramPost
                .where(restaurant_id: @restaurant_id, source: "profile")
                .where(scrapped_at_date: @on_date)
                .order(engagement_score: :desc)
                .limit(3)
      posts.map do |p|
        {
          event_type:  "social_post",
          summary:     p.is_promotional ? "Promo post: #{p.caption&.truncate(80)}" :
                                          "New post: #{p.caption&.truncate(80)}",
          occurred_on: @on_date,
          significance: p.is_promotional ? 3.0 : 1.0,
          details: { post_url: p.post_url, likes: p.likes_count,
                     hashtags: p.hashtags, sentiment: p.caption_sentiment }
        }
      end
    end

    def last_two_scrapes
      @last_two_scrapes ||= RestaurantsScrapped
        .where(restaurant_id: @restaurant_id)
        .where("scrapped_at_date <= ?", @on_date)
        .order(scrapped_at_date: :desc)
        .limit(2)
        .to_a
    end

    def menu_change_summary(e)
      case e.event_type
      when "added"            then "Added #{e.menu_item_name}#{" at ₹#{e.new_price}" if e.new_price}"
      when "removed"          then "Removed #{e.menu_item_name}"
      when "price_increased"  then "#{e.menu_item_name}: ₹#{e.prev_price} → ₹#{e.new_price}"
      when "price_decreased"  then "#{e.menu_item_name}: ₹#{e.prev_price} → ₹#{e.new_price}"
      when "renamed"          then "Renamed #{e.prev_name} → #{e.new_name}"
      else                          "#{e.event_type} #{e.menu_item_name}"
      end
    end

    def significance_for_menu(e)
      case e.event_type
      when "added"           then 2.0
      when "removed"         then 1.5
      when "price_increased",
           "price_decreased" then ((e.price_delta || 0).abs / [e.prev_price.to_f, 1].max) * 5
      else 1.0
      end
    end

    def menu_change_payload(e)
      {
        name:       e.menu_item_name,
        category:   e.category,
        prev_price: e.prev_price,
        new_price:  e.new_price,
        delta:      e.price_delta
      }
    end
  end
end
