module Threat
  # Computes a (pilot, competitor) threat assessment.
  # Numeric overlaps are computed deterministically (so the leaderboard math
  # stays explainable). The LLM only writes the rationale paragraph.
  class Analyzer
    def self.call_for_set(pilot_restaurant_id:, llm_client: Llm::OpenaiClient.default)
      pilot = PilotRestaurant.find(pilot_restaurant_id)
      set   = pilot.active_competitor_set
      return [] if set.nil?

      set.active_members.pluck(:restaurant_id).map do |competitor_id|
        new(pilot: pilot, competitor_id: competitor_id, llm_client: llm_client).call
      end
    end

    def self.call(pilot_restaurant_id:, competitor_restaurant_id:, llm_client: Llm::OpenaiClient.default)
      pilot = PilotRestaurant.find(pilot_restaurant_id)
      new(pilot: pilot, competitor_id: competitor_restaurant_id, llm_client: llm_client).call
    end

    def initialize(pilot:, competitor_id:, llm_client:)
      @pilot       = pilot
      @pilot_r     = pilot.restaurant
      @pilot_snap  = latest_snapshot(@pilot_r)
      @competitor  = Restaurant.find(competitor_id)
      @comp_snap   = latest_snapshot(@competitor)
      @llm         = llm_client
    end

    def call
      scores = compute_scores
      rationale = call_llm(scores)

      ta = ThreatAssessment.find_or_initialize_by(
        pilot_restaurant_id:      @pilot.id,
        competitor_restaurant_id: @competitor.id
      )
      ta.update!(
        segment_overlap:       scores[:segment_overlap],
        cuisine_overlap:       scores[:cuisine_overlap],
        price_band_overlap:    scores[:price_band_overlap],
        neighbourhood_overlap: scores[:neighbourhood_overlap],
        total_threat:          scores[:total_threat],
        rationale:             rationale,
        breakdown:             scores,
        computed_at:           Time.current
      )
      ta
    end

    private

    def compute_scores
      cuisine = jaccard(pilot_cuisines, competitor_cuisines)
      price   = price_band_score
      hood    = neighbourhood_score
      segment = (cuisine * 0.6) + (price * 0.4)
      total   = (cuisine * 0.40) + (price * 0.25) + (hood * 0.25) + (segment * 0.10)

      {
        cuisine_overlap:       cuisine.round(4),
        price_band_overlap:    price.round(4),
        neighbourhood_overlap: hood.round(4),
        segment_overlap:       segment.round(4),
        total_threat:          total.round(4)
      }
    end

    def jaccard(a, b)
      a = a.map(&:downcase); b = b.map(&:downcase)
      return 0.0 if a.empty? || b.empty?
      ((a & b).size).to_f / ((a | b).size)
    end

    def pilot_cuisines
      Array(@pilot_r.primary_cuisines).presence || Array(@pilot_snap&.cuisines)
    end

    def competitor_cuisines
      Array(@competitor.primary_cuisines).presence || Array(@comp_snap&.cuisines)
    end

    def price_band_score
      a = @pilot_r.cost_for_two || @pilot_snap&.cost_for_two
      b = @competitor.cost_for_two || @comp_snap&.cost_for_two
      return 0.0 if a.nil? || b.nil? || a.zero?
      [1.0 - ((a - b).abs.to_f / a), 0.0].max
    end

    def neighbourhood_score
      return 0.0 if @pilot_snap.nil? || @comp_snap.nil?

      direct = [
        @pilot_snap.locality.to_s.casecmp?(@comp_snap.locality.to_s),
        @pilot_snap.area.to_s.casecmp?(@comp_snap.area.to_s)
      ].count(true) / 2.0

      distance = haversine_km(@pilot_r.lat || @pilot_snap.swiggy_lat,
                              @pilot_r.lng || @pilot_snap.swiggy_lng,
                              @competitor.lat || @comp_snap.swiggy_lat,
                              @competitor.lng || @comp_snap.swiggy_lng)
      proximity = if distance.nil?
                    0.0
                  else
                    [1.0 - (distance / 5.0), 0.0].max
                  end
      [direct, proximity].max
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

    def latest_snapshot(r)
      r.scrapes.order(scrapped_at_date: :desc).first
    end

    def call_llm(scores)
      context = {
        pilot: snapshot_summary(@pilot_r, @pilot_snap),
        competitor: snapshot_summary(@competitor, @comp_snap),
        scores: scores
      }

      messages = [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: <<~PROMPT.strip }
          Threat-assessment context:

          ```json
          #{JSON.pretty_generate(context)}
          ```

          Return JSON with one key:
          { "rationale": "2-4 sentences explaining the threat level for the pilot, citing the most important score(s)." }
        PROMPT
      ]

      response = @llm.chat(model: Llm::Models.threat, messages: messages,
                           json: true, temperature: 0.2)
      response["rationale"].to_s
    rescue Llm::OpenaiClient::Error => e
      Rails.logger.warn("[threat] LLM failed for pilot=#{@pilot.id} comp=#{@competitor.id}: #{e.message}")
      "Threat scoring computed; LLM rationale unavailable."
    end

    def snapshot_summary(r, snap)
      {
        name:         r.name,
        cuisines:     Array(r.primary_cuisines).presence || Array(snap&.cuisines),
        cost_for_two: r.cost_for_two || snap&.cost_for_two,
        rating:       r.rating,
        review_count: r.review_count,
        locality:     snap&.locality,
        area:         snap&.area
      }
    end

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You assess how directly a competitor restaurant threatens a pilot restaurant's covers.
      Inputs: deterministic overlap scores (cuisine, price band, neighbourhood) plus snapshots.
      Be specific. Reference the scores by their plain meaning ("they share 80% of cuisines",
      "their cost-for-two sits ₹50 below yours", "they are in the same neighbourhood").
      No hedging, no filler. Strict JSON output only.
    PROMPT
  end
end
