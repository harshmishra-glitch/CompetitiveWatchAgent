module Api
  class CompetitorSetsController < BaseController
    BOOTSTRAP_COOLDOWN = 5.minutes
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
    #
    # On success this also bootstraps the dashboard for this pilot:
    #   - runs Score::CompetitiveHealth inline (fast, no LLM) so the leaderboard
    #     endpoint returns data immediately,
    #   - enqueues BootstrapPilotJob to compute threat assessments + today's
    #     daily digest in the background (~70s for a 6-competitor set).
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

      bootstrap = bootstrap_after_create(pilot, @set)

      render json: {
        competitor_set: set_payload(@set, with_members: true),
        bootstrap:      bootstrap
      }, status: :created
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

    # Inline scoring (cheap, no LLM) + async LLM jobs.
    # Returns the status hash that goes back to the FE.
    def bootstrap_after_create(pilot, set)
      {
        scoring:  run_scoring(set),
        llm_jobs: enqueue_llm_jobs(pilot)
      }
    end

    def run_scoring(set)
      Score::CompetitiveHealth.compute_for_set(competitor_set_id: set.id, date: Date.current)
      { status: "completed", date: Date.current.iso8601 }
    rescue => e
      Rails.logger.error("[bootstrap_pilot] scoring failed: #{e.class}: #{e.message}")
      { status: "failed", error: "#{e.class}: #{e.message}" }
    end

    def enqueue_llm_jobs(pilot)
      force = ActiveModel::Type::Boolean.new.cast(params[:force]) || false

      if !force && pilot.last_bootstrap_at && pilot.last_bootstrap_at > BOOTSTRAP_COOLDOWN.ago
        retry_after = (pilot.last_bootstrap_at + BOOTSTRAP_COOLDOWN - Time.current).to_i.clamp(0, BOOTSTRAP_COOLDOWN.to_i)
        return {
          status:            "skipped",
          reason:            "cooldown",
          last_bootstrap_at: pilot.last_bootstrap_at.iso8601,
          last_job_id:       pilot.last_bootstrap_job_id,
          retry_after:       retry_after,
          polls:             poll_endpoints(pilot)
        }
      end

      job = BootstrapPilotJob.perform_later(pilot.id)
      pilot.update_columns(
        last_bootstrap_at:     Time.current,
        last_bootstrap_job_id: job&.job_id
      )

      {
        status:  "enqueued",
        job:     "BootstrapPilotJob",
        job_id:  job&.job_id,
        forced:  force,
        polls:   poll_endpoints(pilot)
      }
    rescue => e
      Rails.logger.error("[bootstrap_pilot] enqueue failed: #{e.class}: #{e.message}")
      { status: "failed", error: "#{e.class}: #{e.message}" }
    end

    def poll_endpoints(pilot)
      {
        threat_assessments: "/api/pilot_restaurants/#{pilot.id}/threat_assessments",
        daily_digest:       "/api/pilot_restaurants/#{pilot.id}/daily_digest"
      }
    end

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
