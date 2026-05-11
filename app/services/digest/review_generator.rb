module Digest
  class ReviewGenerator
    MAX_REVIEWS_PER_RESTAURANT = 10

    def self.call(pilot_restaurant_id:, date: Date.current, llm_client: Llm::OpenaiClient.default)
      new(pilot_restaurant_id: pilot_restaurant_id, date: date, llm_client: llm_client).call
    end

    def initialize(pilot_restaurant_id:, date:, llm_client:)
      @pilot_restaurant = PilotRestaurant.find(pilot_restaurant_id)
      @date = date
      @llm = llm_client
    end

    def call
      @competitor_set = @pilot_restaurant.active_competitor_set
      context = build_context
      digest = upsert_digest

      if context[:restaurants].all? { |restaurant| restaurant[:reviews].empty? }
        persist(digest, context, {})
        return digest
      end

      llm_response = call_llm(context)
      persist(digest, context, llm_response)
      digest
    end

    private

    def upsert_digest
      digest = ReviewDigest.find_or_initialize_by(
        pilot_restaurant_id: @pilot_restaurant.id,
        competitor_set_id: @competitor_set&.id,
        digest_date: @date
      )
      digest.assign_attributes(status: "draft")
      digest.save!
      digest
    end

    def build_context
      pilot = @pilot_restaurant.restaurant
      competitor_ids = @competitor_set ? @competitor_set.active_members.pluck(:restaurant_id) : []
      restaurants = [pilot, *Restaurant.where(id: competitor_ids)].uniq(&:id)
      reviews_by_restaurant = GoogleReviewScrape
                              .where(restaurant_id: restaurants.map(&:id), scrapped_at_date: @date)
                              .index_by(&:restaurant_id)

      {
        date: @date.iso8601,
        restaurants: restaurants.map do |restaurant|
          raw_reviews = normalize_reviews(reviews_by_restaurant[restaurant.id]&.reviews)
          {
            restaurant_id: restaurant.id,
            name: restaurant.name,
            role: restaurant.id == pilot.id ? "pilot" : "competitor",
            total_reviews: raw_reviews.size,
            reviews: raw_reviews.first(MAX_REVIEWS_PER_RESTAURANT)
          }
        end
      }
    end

    def normalize_reviews(raw_reviews)
      Array(raw_reviews).filter_map do |raw|
        next unless raw.is_a?(Hash)

        review = {
          review_id: raw["review_id"].to_s.strip.presence,
          reviewer_name: raw["reviewer_name"].to_s.strip.presence,
          rating: coerce_float(raw["rating"]),
          review_text: raw["review_text"].to_s.strip.presence,
          likes: coerce_int(raw["likes"]),
          date_raw: raw["date_raw"].to_s.strip.presence,
          local_guide: ActiveModel::Type::Boolean.new.cast(raw["local_guide"])
        }.compact
        next if review.empty?

        review
      end
    end

    def call_llm(context)
      user_prompt = <<~PROMPT
        Restaurant review snippets for #{@date.iso8601}:

        ```json
        #{JSON.pretty_generate(context)}
        ```

        Return strict JSON with this exact shape:
        {
          "restaurants": [
            {
              "restaurant_id": <int>,
              "summary": "1-3 concise sentences summarizing sentiment, recurring praise/issues, and actionable insight"
            }
          ]
        }

        Rules:
        - Include one item for every restaurant in the input.
        - If a restaurant has no reviews, summary must be exactly:
          "No Google reviews found for this day."
        - Use only evidence from provided reviews; do not invent facts.
        - Keep each summary under 280 characters.
      PROMPT

      messages = [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: user_prompt.strip }
      ]

      @llm.chat(model: Llm::Models.review_digest, messages: messages, json: true, temperature: 0.2)
    end

    def persist(digest, context, response)
      summaries = Array(response["restaurants"]).each_with_object({}) do |row, memo|
        next unless row.is_a?(Hash)
        id = row["restaurant_id"].to_i
        next if id <= 0

        memo[id] = row["summary"].to_s.strip
      end

      payload = context[:restaurants].map do |restaurant|
        summary = summaries[restaurant[:restaurant_id]].presence
        summary = "No Google reviews found for this day." if restaurant[:reviews].empty?
        summary ||= "Review signal was mixed with no clear dominant trend."

        {
          restaurant_id: restaurant[:restaurant_id],
          restaurant_name: restaurant[:name],
          role: restaurant[:role],
          total_reviews: restaurant[:total_reviews],
          returned_reviews: restaurant[:reviews].size,
          summary: summary.truncate(280),
          reviews: restaurant[:reviews]
        }
      end

      digest.update!(
        status: "published",
        model_version: Llm::Models.review_digest,
        prompt_context: context,
        reviews_payload: payload,
        generated_at: Time.current
      )
    end

    def coerce_float(value)
      return value.to_f if value.is_a?(Numeric)
      return nil if value.nil?

      str = value.to_s.strip
      return nil if str.empty?

      Float(str)
    rescue ArgumentError, TypeError
      nil
    end

    def coerce_int(value)
      num = coerce_float(value)
      return nil if num.nil?

      num.to_i
    end

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are CLINK's review summarization assistant.
      Write concise, factual summaries for each restaurant based only on provided reviews.
      Focus on recurring patterns in food, service, ambience, pricing, and complaints.
      Output strict JSON only.
    PROMPT
  end
end
