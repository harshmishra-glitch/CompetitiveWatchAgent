module Chatbot
  # Tools the chatbot can call. Each entry has:
  #   - schema: an OpenAI tools[] entry (function definition)
  #   - call: lambda(args, pilot_restaurant) -> Hash (will be JSON-serialized)
  module Tools
    module_function

    def schemas
      definitions.map { |t| { type: "function", function: t[:schema] } }
    end

    def dispatch(name, args, pilot_restaurant)
      tool = definitions.find { |t| t[:schema][:name] == name }
      return { error: "unknown tool: #{name}" } if tool.nil?
      tool[:call].call(args || {}, pilot_restaurant)
    rescue => e
      { error: e.class.name, message: e.message }
    end

    def definitions
      @definitions ||= [
        {
          schema: {
            name: "search_restaurants",
            description: "Search restaurants in CLINK by name. Use to resolve a name to an id.",
            parameters: {
              type: "object",
              properties: {
                q:     { type: "string", description: "Search query (partial name)." },
                limit: { type: "integer", description: "Max rows to return.", default: 10 }
              },
              required: ["q"]
            }
          },
          call: ->(args, _pilot) {
            q = args["q"].to_s.strip
            return { results: [] } if q.empty?
            limit = (args["limit"] || 10).to_i.clamp(1, 50)
            Restaurant
              .where("LOWER(name) LIKE ?", "%#{q.downcase}%")
              .order(Arel.sql("review_count DESC NULLS LAST"))
              .limit(limit)
              .map { |r| { id: r.id, name: r.name, rating: r.rating, review_count: r.review_count } }
              .then { |rows| { results: rows } }
          }
        },
        {
          schema: {
            name: "get_restaurant",
            description: "Get the latest snapshot of one restaurant by id.",
            parameters: {
              type: "object",
              properties: { restaurant_id: { type: "integer" } },
              required: ["restaurant_id"]
            }
          },
          call: ->(args, _pilot) {
            r = Restaurant.find(args["restaurant_id"])
            snap = r.scrapes.order(scrapped_at_date: :desc).first
            {
              id: r.id, name: r.name, rating: r.rating, review_count: r.review_count,
              cuisines: r.primary_cuisines, cost_for_two: r.cost_for_two,
              locality: snap&.locality, area: snap&.area, address: snap&.address,
              latest_snapshot_date: snap&.scrapped_at_date
            }
          }
        },
        {
          schema: {
            name: "get_menu_changes",
            description: "Recent menu changes (added/removed/repriced/renamed) for a restaurant.",
            parameters: {
              type: "object",
              properties: {
                restaurant_id: { type: "integer" },
                since:         { type: "string", description: "e.g. '7d', '30d'.", default: "30d" }
              },
              required: ["restaurant_id"]
            }
          },
          call: ->(args, _pilot) {
            since = parse_since(args["since"], default_days: 30)
            events = MenuChangeEvent
                       .where(restaurant_id: args["restaurant_id"])
                       .since(since)
                       .order(scrapped_at_date: :desc)
                       .limit(100)
            { since: since, events: events.map { |e|
              { event_type: e.event_type, item: e.menu_item_name,
                prev_price: e.prev_price, new_price: e.new_price,
                date: e.scrapped_at_date }
            } }
          }
        },
        {
          schema: {
            name: "get_rating_trend",
            description: "Rating + review-count series for a restaurant.",
            parameters: {
              type: "object",
              properties: {
                restaurant_id: { type: "integer" },
                from:          { type: "string", description: "ISO date." },
                to:            { type: "string", description: "ISO date." }
              },
              required: ["restaurant_id"]
            }
          },
          call: ->(args, _pilot) {
            from = parse_date(args["from"], default: 30.days.ago.to_date)
            to   = parse_date(args["to"],   default: Date.current)
            rows = RestaurantsScrapped
                     .where(restaurant_id: args["restaurant_id"], scrapped_at_date: from..to)
                     .order(:scrapped_at_date)
                     .pluck(:scrapped_at_date, :avg_rating, :total_ratings)
            { from: from, to: to, series: rows.map { |d, ar, tr| { date: d, avg_rating: ar, total_ratings: tr } } }
          }
        },
        {
          schema: {
            name: "get_pricing_analysis",
            description: "Per-category average prices for a restaurant, optionally vs the pilot.",
            parameters: {
              type: "object",
              properties: {
                restaurant_id: { type: "integer" },
                compare_to:    { type: "integer", description: "Pilot restaurant_id to compare against." }
              },
              required: ["restaurant_id"]
            }
          },
          call: ->(args, pilot) {
            target_id = args["restaurant_id"]
            pilot_id  = args["compare_to"] || pilot&.restaurant_id
            target_avgs = category_avgs(target_id)
            pilot_avgs  = pilot_id ? category_avgs(pilot_id) : {}
            categories = (target_avgs.keys | pilot_avgs.keys).map { |cat|
              {
                category: cat,
                target_avg: target_avgs[cat],
                pilot_avg:  pilot_avgs[cat],
                delta:      (target_avgs[cat] && pilot_avgs[cat]) ?
                              (target_avgs[cat] - pilot_avgs[cat]).round(2) : nil
              }
            }
            { target_id: target_id, pilot_id: pilot_id, categories: categories }
          }
        },
        {
          schema: {
            name: "get_activity_feed",
            description: "Chronological detected events for a restaurant.",
            parameters: {
              type: "object",
              properties: {
                restaurant_id: { type: "integer" },
                since:         { type: "string", default: "14d" },
                types:         { type: "string", description: "Comma-separated event_types." }
              },
              required: ["restaurant_id"]
            }
          },
          call: ->(args, _pilot) {
            since = parse_since(args["since"], default_days: 14)
            types = args["types"].to_s.split(",").map(&:strip).reject(&:empty?)
            events = CompetitorActivityEvent
                       .where(restaurant_id: args["restaurant_id"])
                       .since(since)
                       .of_types(types)
                       .order(occurred_on: :desc, significance: :desc)
                       .limit(100)
            { since: since, events: events.map { |e|
              { type: e.event_type, summary: e.summary, on: e.occurred_on,
                significance: e.significance }
            } }
          }
        },
        {
          schema: {
            name: "get_social_signals",
            description: "Recent Instagram posts (own handle + tagged) for a restaurant.",
            parameters: {
              type: "object",
              properties: {
                restaurant_id: { type: "integer" },
                since:         { type: "string", default: "14d" }
              },
              required: ["restaurant_id"]
            }
          },
          call: ->(args, _pilot) {
            since = parse_since(args["since"], default_days: 14)
            posts = InstagramPost
                      .where(restaurant_id: args["restaurant_id"])
                      .where("posted_at >= ?", since)
                      .order(posted_at: :desc)
                      .limit(50)
            { since: since, posts: posts.map { |p|
              { source: p.source, posted_at: p.posted_at,
                caption: p.caption&.truncate(180), likes: p.likes_count,
                is_promotional: p.is_promotional, sentiment: p.caption_sentiment }
            } }
          }
        },
        {
          schema: {
            name: "get_leaderboard",
            description: "Competitive Health Score leaderboard for the pilot's active competitor set.",
            parameters: {
              type: "object",
              properties: {
                date:              { type: "string", description: "ISO date.", default: "today" },
                competitor_set_id: { type: "integer", description: "Defaults to pilot's active set." }
              }
            }
          },
          call: ->(args, pilot) {
            date = parse_date(args["date"], default: Date.current)
            set_id = args["competitor_set_id"] || pilot&.active_competitor_set&.id
            return { error: "no competitor set" } if set_id.nil?
            set = CompetitorSet.find(set_id)
            ids = (set.active_members.pluck(:restaurant_id) + [set.pilot_restaurant.restaurant_id]).uniq
            scores = CompetitiveHealthScore
                       .where(restaurant_id: ids, score_date: date)
                       .order(:rank_in_set)
            names = Restaurant.where(id: ids).pluck(:id, :name).to_h
            { date: date, rows: scores.map { |s|
              { restaurant_id: s.restaurant_id, name: names[s.restaurant_id],
                rank: s.rank_in_set, score: s.total_score,
                delta_7d: s.score_delta_7d, headline: s.headline_signal,
                is_pilot: s.restaurant_id == set.pilot_restaurant.restaurant_id }
            } }
          }
        },
        {
          schema: {
            name: "get_recent_reviews",
            description: "Recent Google reviews for a restaurant — useful for sentiment / complaint analysis and quoting customer feedback.",
            parameters: {
              type: "object",
              properties: {
                restaurant_id: { type: "integer" },
                since:         { type: "string", description: "e.g. '7d', '30d'.", default: "30d" },
                limit:         { type: "integer", description: "Max reviews to return.", default: 20 }
              },
              required: ["restaurant_id"]
            }
          },
          call: ->(args, _pilot) {
            since = parse_since(args["since"], default_days: 30)
            limit = (args["limit"] || 20).to_i.clamp(1, 50)
            scrapes = GoogleReviewScrape
                        .where(restaurant_id: args["restaurant_id"])
                        .where("scrapped_at_date >= ?", since)
                        .order(scrapped_at_date: :desc)
            reviews = scrapes.flat_map { |s| Array(s.reviews) }.first(limit)
            ratings = reviews.map { |r| r["rating"] }.compact
            avg = ratings.any? ? (ratings.sum.to_f / ratings.size).round(2) : nil
            {
              since:      since,
              count:      reviews.size,
              avg_rating: avg,
              reviews:    reviews.map { |r|
                { rating: r["rating"], reviewer: r["reviewer_name"],
                  text: r["review_text"]&.then { |t| t.length > 250 ? t[0, 247] + "..." : t },
                  date: r["date_raw"], likes: r["likes"] }
              }
            }
          }
        },
        {
          schema: {
            name: "get_threat_assessments",
            description: "Pre-computed threat scores for the pilot vs each competitor.",
            parameters: { type: "object", properties: {} }
          },
          call: ->(_args, pilot) {
            return { error: "no pilot" } if pilot.nil?
            rows = ThreatAssessment
                     .where(pilot_restaurant_id: pilot.id)
                     .order(total_threat: :desc)
            names = Restaurant.where(id: rows.map(&:competitor_restaurant_id)).pluck(:id, :name).to_h
            { rows: rows.map { |t|
              { competitor: names[t.competitor_restaurant_id],
                total_threat: t.total_threat,
                segment_overlap: t.segment_overlap,
                price_band_overlap: t.price_band_overlap,
                neighbourhood_overlap: t.neighbourhood_overlap,
                cuisine_overlap: t.cuisine_overlap,
                rationale: t.rationale }
            } }
          }
        },
        {
          schema: {
            name: "get_daily_digest",
            description: "Today's (or a specific date's) daily digest for the pilot.",
            parameters: {
              type: "object",
              properties: { date: { type: "string", description: "ISO date." } }
            }
          },
          call: ->(args, pilot) {
            return { error: "no pilot" } if pilot.nil?
            date = parse_date(args["date"], default: Date.current)
            return { error: "future_date", date: date } if date > Date.current

            digest = DailyDigest.fetch_or_generate(pilot_restaurant_id: pilot.id, date: date)
            {
              date: date,
              summary: digest.summary,
              quiet_day: digest.quiet_day,
              cards: digest.digest_competitor_cards.order(priority: :desc).map { |c|
                { competitor_restaurant_id: c.competitor_restaurant_id,
                  change_summary: c.change_summary, why_it_matters: c.why_it_matters,
                  recommendation: c.recommendation, rationale: c.rationale }
              }
            }
          }
        }
      ]
    end

    # ---- helpers ----

    def parse_date(value, default:)
      return default if value.blank? || value.to_s.casecmp?("today")
      Date.parse(value.to_s)
    rescue ArgumentError
      default
    end

    def parse_since(value, default_days:)
      return default_days.days.ago.to_date if value.blank?
      m = value.to_s.match(/\A(\d+)([dDwWmM])\z/)
      if m
        unit = { "d" => :days, "w" => :weeks, "m" => :months }[m[2].downcase]
        return m[1].to_i.public_send(unit).ago.to_date
      end
      Date.parse(value.to_s)
    rescue ArgumentError
      default_days.days.ago.to_date
    end

    def category_avgs(restaurant_id)
      snap = RestaurantsScrapped
               .where(restaurant_id: restaurant_id)
               .order(scrapped_at_date: :desc)
               .first
      return {} if snap.nil?
      MenuItem.where(restaurants_scrapped_id: snap.id)
              .where.not(price: nil)
              .group(:category)
              .average(:price)
              .transform_values { |v| v.to_f.round(2) }
    end
  end
end
