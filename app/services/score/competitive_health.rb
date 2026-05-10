module Score
  # Computes the Competitive Health Score for every restaurant in a competitor
  # set on a given date. Pure-Ruby; no LLM.
  #
  # Score is a weighted composite of six 0..1 components:
  #
  #   rating_trajectory  : avg_rating delta over last 7 days (mapped from -0.3..+0.3)
  #   review_velocity    : new total_ratings / day, normalized vs the set max
  #   menu_activity      : count of menu changes in last 7d, normalized vs set max
  #   social_mentions    : 7-day Instagram engagement, normalized vs set max
  #   serp_visibility    : 1/position of best organic SERP result
  #   estimated_demand   : weighted blend of velocity + social + trajectory
  #
  # All set-relative metrics are normalized within the set so the leaderboard
  # has meaningful spread even when absolute numbers are tiny.
  class CompetitiveHealth
    WEIGHTS = {
      rating_trajectory: 0.25,
      review_velocity:   0.20,
      menu_activity:     0.15,
      social_mentions:   0.15,
      serp_visibility:   0.10,
      estimated_demand:  0.15
    }.freeze

    RATING_TRAJECTORY_RANGE = 0.3   # ±0.3 stars maps to 0..1

    def self.compute_for_set(competitor_set_id:, date: Date.current)
      new(competitor_set_id: competitor_set_id, date: date).call
    end

    def self.compute_all(date: Date.current)
      CompetitorSet.where(active: true).find_each.map do |set|
        compute_for_set(competitor_set_id: set.id, date: date)
      end
    end

    def initialize(competitor_set_id:, date:)
      @set  = CompetitorSet.find(competitor_set_id)
      @date = date
    end

    def call
      restaurant_ids = (@set.active_members.pluck(:restaurant_id) +
                        [@set.pilot_restaurant.restaurant_id]).uniq
      raw = restaurant_ids.index_with { |rid| raw_features(rid) }

      norms = {
        review_velocity: max_or_one(raw.values.map { |f| f[:review_velocity_raw] }),
        menu_activity:   max_or_one(raw.values.map { |f| f[:menu_changes_raw] }),
        social_mentions: max_or_one(raw.values.map { |f| f[:social_engagement_raw] })
      }

      computed = raw.transform_values { |f| score_components(f, norms) }

      ranked = computed.sort_by { |_, c| -c[:total_score] }
      ranked.each_with_index do |(rid, c), i|
        upsert_row(rid, c, rank: i + 1)
      end
      ranked.map(&:first)
    end

    private

    def score_components(f, norms)
      rating_pos = clamp01((f[:rating_delta_7d].to_f + RATING_TRAJECTORY_RANGE) /
                           (RATING_TRAJECTORY_RANGE * 2))
      review_vel = clamp01(f[:review_velocity_raw].to_f / norms[:review_velocity])
      menu_act   = clamp01(f[:menu_changes_raw].to_f   / norms[:menu_activity])
      social     = clamp01(f[:social_engagement_raw].to_f / norms[:social_mentions])
      serp       = serp_to_score(f[:serp_top_position])
      demand     = clamp01(0.5 * review_vel + 0.3 * social + 0.2 * rating_pos)

      total = (
        WEIGHTS[:rating_trajectory] * rating_pos +
        WEIGHTS[:review_velocity]   * review_vel +
        WEIGHTS[:menu_activity]     * menu_act +
        WEIGHTS[:social_mentions]   * social +
        WEIGHTS[:serp_visibility]   * serp +
        WEIGHTS[:estimated_demand]  * demand
      ) * 100

      {
        total_score:       total.round(2),
        rating_trajectory: rating_pos.round(4),
        review_velocity:   review_vel.round(4),
        menu_activity:     menu_act.round(4),
        social_mentions:   social.round(4),
        serp_visibility:   serp.round(4),
        estimated_demand:  demand.round(4),
        headline_signal:   build_headline(f, rating_pos, menu_act, social, review_vel),
        breakdown:         f
      }
    end

    def raw_features(restaurant_id)
      today_snap   = scrape_for(restaurant_id, @date,            exact: true)
      week_ago     = scrape_for(restaurant_id, @date - 7.days,   exact: false)

      rating_today = today_snap&.avg_rating&.to_f
      rating_week  = week_ago&.avg_rating&.to_f
      rating_delta = (rating_today && rating_week) ? (rating_today - rating_week) : 0.0

      ratings_today = today_snap&.total_ratings.to_i
      ratings_week  = week_ago&.total_ratings.to_i
      review_velocity = if ratings_today > 0 && ratings_week > 0
                          [(ratings_today - ratings_week) / 7.0, 0].max
                        else
                          0.0
                        end

      {
        rating_today:           rating_today,
        rating_week_ago:        rating_week,
        rating_delta_7d:        rating_delta.round(3),
        review_velocity_raw:    review_velocity.round(2),
        ratings_today:          ratings_today,
        ratings_week_ago:       ratings_week,
        menu_changes_raw:       count_menu_changes(restaurant_id, today_snap, week_ago),
        social_engagement_raw:  social_engagement(restaurant_id),
        serp_top_position:      serp_top_position(restaurant_id)
      }
    end

    def scrape_for(restaurant_id, on_date, exact:)
      scope = RestaurantsScrapped.where(restaurant_id: restaurant_id)
      scope = exact ? scope.where(scrapped_at_date: on_date) :
                      scope.where("scrapped_at_date <= ?", on_date)
      scope.order(scrapped_at_date: :desc).first
    end

    def count_menu_changes(restaurant_id, today_snap, week_ago_snap)
      persisted = MenuChangeEvent
                    .where(restaurant_id: restaurant_id,
                           scrapped_at_date: (@date - 7.days)..@date)
                    .count
      return persisted if persisted.positive?
      return 0 if today_snap.nil? || week_ago_snap.nil? || today_snap.id == week_ago_snap.id

      today_items = MenuItem.where(restaurants_scrapped_id: today_snap.id)
                            .pluck(:name, :price).to_h
      old_items   = MenuItem.where(restaurants_scrapped_id: week_ago_snap.id)
                            .pluck(:name, :price).to_h
      added    = (today_items.keys - old_items.keys).size
      removed  = (old_items.keys   - today_items.keys).size
      repriced = (today_items.keys & old_items.keys).count { |n| today_items[n] != old_items[n] }
      added + removed + repriced
    end

    def social_engagement(restaurant_id)
      InstagramPost
        .where(restaurant_id: restaurant_id)
        .where(scrapped_at_date: (@date - 7.days)..@date)
        .sum(Arel.sql("COALESCE(engagement_score, likes_count, 0)"))
        .to_i
    end

    def serp_top_position(restaurant_id)
      SerpOrganicResult
        .joins(:google_serp_scrape)
        .where(restaurant_id: restaurant_id, result_type: "organic")
        .where("google_serp_scrapes.scrapped_at_date <= ?", @date)
        .order("google_serp_scrapes.scrapped_at_date DESC, position ASC")
        .limit(1)
        .pick(:position)
    end

    def serp_to_score(position)
      return 0.0 if position.nil?
      (1.0 / position.to_f).clamp(0.0, 1.0)
    end

    def upsert_row(restaurant_id, c, rank:)
      prev = CompetitiveHealthScore.find_by(
        restaurant_id: restaurant_id,
        score_date:    @date - 7.days
      )
      delta_7d = prev && prev.total_score ? (c[:total_score] - prev.total_score.to_f).round(2) : nil

      chs = CompetitiveHealthScore.find_or_initialize_by(
        restaurant_id: restaurant_id,
        score_date:    @date
      )
      chs.update!(
        competitor_set_id: @set.id,
        total_score:       c[:total_score],
        rating_trajectory: c[:rating_trajectory],
        review_velocity:   c[:review_velocity],
        menu_activity:     c[:menu_activity],
        social_mentions:   c[:social_mentions],
        serp_visibility:   c[:serp_visibility],
        estimated_demand:  c[:estimated_demand],
        rank_in_set:       rank,
        score_delta_7d:    delta_7d,
        headline_signal:   c[:headline_signal],
        breakdown:         c[:breakdown]
      )
    end

    def build_headline(f, _rating_pos, menu_act, social, review_vel)
      candidates = []

      if f[:rating_delta_7d].is_a?(Numeric) && f[:rating_delta_7d].abs >= 0.1
        verb = f[:rating_delta_7d].positive? ? "rose" : "dropped"
        candidates << ["Rating #{verb} #{f[:rating_delta_7d].abs.round(2)} in 7 days",
                       f[:rating_delta_7d].abs * 5]
      end
      if f[:menu_changes_raw] >= 3
        candidates << ["#{f[:menu_changes_raw]} menu changes this week", menu_act + 0.2]
      end
      if f[:social_engagement_raw] >= 100
        candidates << ["Trending on Instagram (#{f[:social_engagement_raw]} engagement)",
                       social + 0.1]
      end
      if f[:review_velocity_raw] >= 2
        candidates << ["Review volume up #{f[:review_velocity_raw].round(1)}/day", review_vel + 0.1]
      end

      return "Steady" if candidates.empty?
      candidates.max_by { |_, weight| weight }.first
    end

    def max_or_one(values)
      m = values.compact.max.to_f
      m.zero? ? 1.0 : m
    end

    def clamp01(v)
      v.to_f.clamp(0.0, 1.0)
    end
  end
end
