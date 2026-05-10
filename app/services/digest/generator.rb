module Digest
  # Builds a Daily Digest for one pilot on one date by:
  #   1. Collecting yesterday's events for the pilot + each active competitor.
  #   2. Asking the LLM to write the 2-3 sentence overall briefing AND
  #      one card per competitor with change_summary / why_it_matters /
  #      recommendation (defend|watch|ignore) / rationale / priority.
  #   3. Persisting the structured response into daily_digests + cards.
  class Generator
    def self.call(pilot_restaurant_id:, date: Date.current, llm_client: Llm::OpenaiClient.default)
      new(pilot_restaurant_id: pilot_restaurant_id, date: date, llm_client: llm_client).call
    end

    def initialize(pilot_restaurant_id:, date:, llm_client:)
      @pilot_restaurant = PilotRestaurant.find(pilot_restaurant_id)
      @date             = date
      @llm              = llm_client
    end

    def call
      @competitor_set = @pilot_restaurant.active_competitor_set
      context = build_context
      digest  = upsert_digest(quiet_day: context[:competitors].all? { |c| c[:events].empty? } &&
                                          context[:pilot][:events].empty?)

      if digest.quiet_day
        digest.update!(
          summary:       quiet_day_summary,
          status:        "published",
          generated_at:  Time.current,
          model_version: Llm::Models.digest,
          prompt_context: context
        )
        digest.digest_competitor_cards.delete_all
        return digest
      end

      llm_response = call_llm(context)
      persist_response(digest, context, llm_response)
      digest
    end

    private

    def build_context
      pilot_restaurant = @pilot_restaurant.restaurant
      competitor_ids = @competitor_set ? @competitor_set.active_members.pluck(:restaurant_id) : []

      {
        date: @date.iso8601,
        pilot: {
          restaurant_id: pilot_restaurant.id,
          name:          pilot_restaurant.name,
          cuisines:      pilot_restaurant.primary_cuisines,
          cost_for_two:  pilot_restaurant.cost_for_two,
          rating:        pilot_restaurant.rating,
          review_count:  pilot_restaurant.review_count,
          events:        EventCollector.for(restaurant_id: pilot_restaurant.id, on_date: @date)
        },
        competitors: Restaurant.where(id: competitor_ids).map { |c|
          {
            restaurant_id: c.id,
            name:          c.name,
            cuisines:      c.primary_cuisines,
            cost_for_two:  c.cost_for_two,
            rating:        c.rating,
            review_count:  c.review_count,
            events:        EventCollector.for(restaurant_id: c.id, on_date: @date)
          }
        }
      }
    end

    def upsert_digest(quiet_day:)
      digest = DailyDigest.find_or_initialize_by(
        pilot_restaurant_id: @pilot_restaurant.id,
        competitor_set_id:   @competitor_set&.id,
        digest_date:         @date
      )
      digest.assign_attributes(
        summary:   digest.summary || "",
        quiet_day: quiet_day,
        status:    "draft"
      )
      digest.save!
      digest
    end

    def quiet_day_summary
      "No significant changes today across your pilot or your tracked competitors."
    end

    def call_llm(context)
      messages = [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user",   content: <<~PROMPT.strip }
          Pilot restaurant and competitor activity for #{@date.iso8601}:

          ```json
          #{JSON.pretty_generate(context)}
          ```

          Produce a JSON object with this exact shape:
          {
            "summary": "2-3 sentence plain-language briefing of today's most important competitive development",
            "cards": [
              {
                "competitor_restaurant_id": <int>,
                "change_summary": "what changed",
                "why_it_matters": "why it matters to the pilot specifically",
                "recommendation": "defend" | "watch" | "ignore",
                "rationale": "one-line rationale for the recommendation",
                "priority": <float 0..1>
              }
            ]
          }

          Rules:
          - Emit one card per competitor that had activity today; skip competitors whose `events` array is empty.
          - "defend" only when the competitor's move directly threatens the pilot's price band, cuisine, or neighbourhood.
          - "watch" for moderate moves worth tracking but not urgent.
          - "ignore" for noise that doesn't affect the pilot.
          - Refer to numbers explicitly when present (prices, rating deltas).
          - Keep change_summary under 140 chars and why_it_matters under 200.
        PROMPT
      ]

      @llm.chat(model: Llm::Models.digest, messages: messages, json: true, temperature: 0.2)
    end

    def persist_response(digest, context, response)
      summary = response["summary"].to_s.strip
      cards   = Array(response["cards"])

      ActiveRecord::Base.transaction do
        digest.update!(
          summary:        summary.presence || quiet_day_summary,
          status:         "published",
          generated_at:   Time.current,
          model_version:  Llm::Models.digest,
          prompt_context: context
        )

        digest.digest_competitor_cards.delete_all
        cards.each do |card|
          recommendation = card["recommendation"].to_s.downcase
          next unless DigestCompetitorCard::RECOMMENDATIONS.include?(recommendation)

          competitor_id = card["competitor_restaurant_id"].to_i
          next unless context[:competitors].any? { |c| c[:restaurant_id] == competitor_id }

          digest.digest_competitor_cards.create!(
            competitor_restaurant_id: competitor_id,
            change_summary: card["change_summary"].to_s.truncate(280),
            why_it_matters: card["why_it_matters"].to_s.truncate(400),
            recommendation: recommendation,
            rationale:      card["rationale"].to_s.truncate(280),
            priority:       card["priority"].to_f.clamp(0, 1)
          )
        end
      end
    end

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are CLINK's Daily Digest writer for restaurant owners.
      Your job: turn raw competitor activity into a tight, actionable briefing.

      Voice: plain language, no marketing fluff, no hedging. Short, punchy sentences.
      Lead with the single most important development of the day.
      Numbers and concrete moves beat adjectives.

      Recommendations follow a strict bias-to-action rubric:
      - defend: a competitor's move directly threatens the pilot's covers (overlapping cuisine
        AND similar price band AND same neighbourhood, or a clear pricing attack).
      - watch:  a notable move worth knowing but no immediate response required.
      - ignore: noise — irrelevant to the pilot's segment.

      Output: strict JSON only, no prose, no markdown fences.
    PROMPT
  end
end
