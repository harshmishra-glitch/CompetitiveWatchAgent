module Api
  class CompetitorSetsController < BaseController
    # GET /api/competitor_sets?pilot_restaurant_id=
    def index
      pilot_id = params[:pilot_restaurant_id].presence || current_pilot_restaurant&.id
      return render_error(:bad_request, "missing_pilot", "pilot_restaurant_id required") if pilot_id.nil?

      sets = CompetitorSet.where(pilot_restaurant_id: pilot_id).order(created_at: :desc)
      render json: { competitor_sets: sets.map { |s| set_payload(s) } }
    end

    # GET /api/competitor_sets/:id
    def show
      set = CompetitorSet.find(params[:id])
      render json: { competitor_set: set_payload(set, with_members: true) }
    end

    # POST /api/competitor_sets
    # Body: { pilot_restaurant_id, restaurant_ids: [..], name? }
    def create
      pilot_id       = params.require(:pilot_restaurant_id)
      restaurant_ids = Array(params[:restaurant_ids]).map(&:to_i).uniq

      pilot = PilotRestaurant.find(pilot_id)

      ActiveRecord::Base.transaction do
        # only one active set per pilot
        CompetitorSet.where(pilot_restaurant_id: pilot.id).update_all(active: false)
        @set = CompetitorSet.create!(
          pilot_restaurant_id: pilot.id,
          name:                params[:name],
          active:              true
        )
        now = Time.current
        rows = restaurant_ids.map do |rid|
          { competitor_set_id: @set.id, restaurant_id: rid,
            source: "suggested", added_at: now,
            created_at: now, updated_at: now }
        end
        CompetitorSetMember.insert_all!(rows) if rows.any?
      end

      render json: { competitor_set: set_payload(@set, with_members: true) }, status: :created
    end

    # GET /api/competitor_sets/:id/leaderboard?date=
    def leaderboard
      set = CompetitorSet.find(params[:id])
      date = parse_date(params[:date], default: Date.current)

      member_ids = set.active_members.pluck(:restaurant_id)
      pilot_id   = set.pilot_restaurant.restaurant_id
      restaurant_ids = (member_ids + [pilot_id]).uniq

      scores = CompetitiveHealthScore
                 .where(restaurant_id: restaurant_ids, score_date: date)
                 .order(:rank_in_set, total_score: :desc)
                 .index_by(&:restaurant_id)

      restaurants = Restaurant.where(id: restaurant_ids).index_by(&:id)

      rows = restaurant_ids.map { |rid|
        s = scores[rid]
        r = restaurants[rid]
        next nil if r.nil?
        {
          restaurant_id: rid,
          name:          r.name,
          rank:          s&.rank_in_set,
          total_score:   s&.total_score,
          score_delta_7d: s&.score_delta_7d,
          headline_signal: s&.headline_signal,
          is_pilot:      rid == pilot_id
        }
      }.compact.sort_by { |row| [row[:rank] || Float::INFINITY, -(row[:total_score].to_f)] }

      render json: { date: date, leaderboard: rows }
    end

    # GET /api/competitor_sets/:id/leaderboard/history?from=&to=
    def leaderboard_history
      set = CompetitorSet.find(params[:id])
      from = parse_date(params[:from], default: 30.days.ago.to_date)
      to   = parse_date(params[:to],   default: Date.current)

      member_ids = set.active_members.pluck(:restaurant_id)
      pilot_id   = set.pilot_restaurant.restaurant_id
      restaurant_ids = (member_ids + [pilot_id]).uniq

      series = CompetitiveHealthScore
                 .where(restaurant_id: restaurant_ids, score_date: from..to)
                 .order(:score_date)
                 .group_by(&:restaurant_id)

      render json: {
        from: from, to: to,
        history: series.transform_values { |arr|
          arr.map { |s| { date: s.score_date, total_score: s.total_score, rank: s.rank_in_set } }
        }
      }
    end

    private

    def set_payload(set, with_members: false)
      base = {
        id: set.id,
        pilot_restaurant_id: set.pilot_restaurant_id,
        name: set.name,
        active: set.active,
        created_at: set.created_at,
        member_count: set.active_members.count
      }
      return base unless with_members

      base.merge(
        members: set.active_members.includes(:restaurant).map { |m|
          {
            id: m.id,
            restaurant_id: m.restaurant_id,
            name: m.restaurant.name,
            source: m.source,
            added_at: m.added_at
          }
        }
      )
    end
  end
end
