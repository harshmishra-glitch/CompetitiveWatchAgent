module Api
  class PilotRestaurantsController < BaseController
    # GET /api/pilot_restaurants
    def index
      pilots = PilotRestaurant.includes(:restaurant).order(set_at: :desc)
      render json: { pilot_restaurants: pilots.map { |p| pilot_payload(p) } }
    end

    # GET /api/pilot_restaurants/current
    def current
      pilot = current_pilot_restaurant
      return render_error(:not_found, "no_pilot_restaurant", "No active pilot restaurant.") if pilot.nil?
      render json: { pilot_restaurant: pilot_payload(pilot) }
    end

    # GET /api/pilot_restaurants/:id
    def show
      pilot = PilotRestaurant.find(params[:id])
      render json: { pilot_restaurant: pilot_payload(pilot) }
    end

    # POST /api/pilot_restaurants
    # Body: { restaurant_id }
    def create
      restaurant_id = params.require(:restaurant_id)
      restaurant = Restaurant.find(restaurant_id)

      pilot = PilotRestaurant.find_or_initialize_by(restaurant_id: restaurant.id)
      pilot.update!(active: true, set_at: Time.current)
      PilotRestaurant.where.not(id: pilot.id).update_all(active: false)

      render json: { pilot_restaurant: pilot_payload(pilot) }, status: :created
    end

    # GET /api/pilot_restaurants/:id/suggested_competitors?limit=
    def suggested_competitors
      pilot = PilotRestaurant.find(params[:id])
      limit = (params[:limit].presence || Competitors::Suggester::DEFAULT_LIMIT).to_i.clamp(1, 50)
      suggestions = Competitors::Suggester.call(pilot_restaurant: pilot, limit: limit)
      render json: { suggestions: suggestions }
    end

    # GET /api/pilot_restaurants/:id/threat_assessments
    def threat_assessments
      pilot = PilotRestaurant.find(params[:id])
      rows = ThreatAssessment
               .where(pilot_restaurant_id: pilot.id)
               .order(total_threat: :desc)
      render json: {
        threat_assessments: rows.map { |t| threat_payload(t) }
      }
    end

    # GET /api/pilot_restaurants/:id/daily_digest?date=
    def daily_digest
      pilot = PilotRestaurant.find(params[:id])
      date  = parse_date(params[:date], default: Date.current)
      return render_error(:bad_request, "future_date", "Cannot generate a digest for a future date") if date > Date.current

      digest = DailyDigest.fetch_or_generate(pilot_restaurant_id: pilot.id, date: date)
      render json: { daily_digest: digest_payload(digest) }
    end

    # GET /api/pilot_restaurants/:id/daily_digests?from=&to=
    def daily_digests
      pilot = PilotRestaurant.find(params[:id])
      from = parse_date(params[:from], default: 30.days.ago.to_date)
      to   = parse_date(params[:to],   default: Date.current)

      digests = DailyDigest
                  .where(pilot_restaurant_id: pilot.id, digest_date: from..to)
                  .order(digest_date: :desc)

      render json: {
        from: from, to: to,
        daily_digests: digests.map { |d| digest_summary(d) }
      }
    end

    # GET /api/pilot_restaurants/:id/suggested_questions
    def suggested_questions
      pilot = PilotRestaurant.find(params[:id])
      render json: Chatbot::QuestionSuggester.call(pilot)
    end

    private

    def pilot_payload(pilot)
      r = pilot.restaurant
      {
        id: pilot.id,
        active: pilot.active,
        set_at: pilot.set_at,
        restaurant: { id: r.id, name: r.name, rating: r.rating, review_count: r.review_count },
        active_competitor_set_id: pilot.active_competitor_set&.id
      }
    end

    def threat_payload(t)
      {
        id: t.id,
        competitor_restaurant_id: t.competitor_restaurant_id,
        segment_overlap: t.segment_overlap,
        price_band_overlap: t.price_band_overlap,
        neighbourhood_overlap: t.neighbourhood_overlap,
        cuisine_overlap: t.cuisine_overlap,
        total_threat: t.total_threat,
        rationale: t.rationale,
        computed_at: t.computed_at
      }
    end

    def digest_summary(d)
      { id: d.id, digest_date: d.digest_date, summary: d.summary,
        quiet_day: d.quiet_day, status: d.status }
    end

    def digest_payload(d)
      cards = d.digest_competitor_cards.order(priority: :desc)
      {
        id: d.id, digest_date: d.digest_date, summary: d.summary,
        quiet_day: d.quiet_day, status: d.status,
        generated_at: d.generated_at,
        cards: cards.map { |c|
          {
            id: c.id,
            competitor_restaurant_id: c.competitor_restaurant_id,
            change_summary: c.change_summary,
            why_it_matters: c.why_it_matters,
            recommendation: c.recommendation,
            rationale: c.rationale,
            priority: c.priority
          }
        }
      }
    end
  end
end
