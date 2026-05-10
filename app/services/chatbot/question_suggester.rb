module Chatbot
  # Generates a personalized list of question suggestions for the chatbot,
  # based on the pilot's actual competitor set + the most recent computed signals.
  # Used by GET /api/pilot_restaurants/:id/suggested_questions to populate
  # category chips and the empty-state starter prompts in the UI.
  module QuestionSuggester
    module_function

    CATEGORIES = [
      { name: "digest",             label: "What changed" },
      { name: "threat",             label: "Competitive threats" },
      { name: "leaderboard",        label: "Rankings" },
      { name: "pricing",            label: "Pricing" },
      { name: "menu",               label: "Menu changes" },
      { name: "ratings",            label: "Ratings & reviews" },
      { name: "social",             label: "Social signals" },
      { name: "competitor_profile", label: "Competitor profiles" },
      { name: "action",             label: "What should I do" }
    ].freeze

    def self.call(pilot_restaurant)
      new_context(pilot_restaurant).build
    end

    def self.new_context(pilot_restaurant)
      Context.new(pilot_restaurant)
    end

    class Context
      def initialize(pilot_restaurant)
        @pilot      = pilot_restaurant
        @pilot_name = brand_short_name(pilot_restaurant.restaurant.name)
        @set        = pilot_restaurant.active_competitor_set
        @members    = if @set
                        @set.active_members
                            .includes(:restaurant)
                            .map(&:restaurant)
                            .reject { |r| r.id == pilot_restaurant.restaurant_id }
                      else
                        []
                      end
        @top_threat = top_threat_competitor
      end

      def build
        categories = CATEGORIES.map do |c|
          {
            name:      c[:name],
            label:     c[:label],
            questions: send("#{c[:name]}_questions")
          }
        end

        {
          pilot_restaurant_id: @pilot.id,
          pilot_name:          @pilot_name,
          competitor_count:    @members.size,
          starter_chips:       starter_chips,
          categories:          categories
        }
      end

      # ---- starter empty-state chips (max 4, deterministic) ----
      def starter_chips
        chips = ["What changed yesterday across my competitors?"]
        chips << "Who is my biggest competitive threat right now?" if @top_threat
        chips << "How does my pricing compare to my competitors?"  if @members.any?
        chips << "Who is growing fastest in my segment right now?" if @members.any?
        chips.first(4)
      end

      # ---- per-category questions ----
      def digest_questions
        [
          "What's today's briefing?",
          "What changed yesterday across my competitors?",
          "Catch me up on the last 7 days.",
          "Anything I should respond to this week?"
        ]
      end

      def threat_questions
        list = ["Who is my biggest competitive threat right now?"]
        list << "Should I be worried about #{@top_threat}?" if @top_threat
        list << "Who overlaps with me most in cuisine and price?"
        list << "Is #{@members.first.name} a direct threat?" if @members.any?
        list
      end

      def leaderboard_questions
        [
          "Where do I rank against my competitors?",
          "Who is growing fastest in my segment right now?",
          "Who has the highest competitive health score?",
          "Has my rank moved this week?"
        ]
      end

      def pricing_questions
        list = ["How does my pricing compare to my competitors?"]
        list << "Where are my Coffee prices vs the market average?"
        list << "Is #{@pilot_name} pricing above or below #{@members.first.name}?" if @members.any?
        list << "Which competitor is the cheapest per category?"
        list
      end

      def menu_questions
        list = ["Did anyone change their menu this week?"]
        list << "Show me all menu changes for #{@members.first.name} in the last 14 days." if @members.any?
        list << "Which competitor launched the most new items recently?"
        list << "Are any competitors dropping prices?"
        list
      end

      def ratings_questions
        list = ["Whose rating dropped this week?"]
        list << "Has my Google rating moved?"
        list << "Which competitor has the fastest-growing review count?"
        list << "How is #{(@members[1] || @members.first)&.name} rated lately?" if @members.any?
        list.compact
      end

      def social_questions
        list = ["Who's trending on Instagram?"]
        list << "Show me #{@pilot_name}'s recent Instagram posts."
        list << "Has anyone been running promotional posts lately?"
        list << "Which competitors are most active on social?"
        list
      end

      def competitor_profile_questions
        list = []
        @members.first(3).each { |m| list << "How is #{m.name} doing this month?" }
        list << "Give me a snapshot of #{@members.last.name} right now." if @members.size > 3
        list.first(4)
      end

      def action_questions
        list = ["What should I do to defend my lunch covers this week?"]
        list << "How can I respond to #{@top_threat}'s recent moves?" if @top_threat
        list << "Where am I most exposed competitively?"
        list << "Which one card from today's digest should I act on first?"
        list
      end

      private

      def top_threat_competitor
        row = ThreatAssessment
                .where(pilot_restaurant_id: @pilot.id)
                .order(total_threat: :desc)
                .first
        return nil if row.nil?
        Restaurant.find_by(id: row.competitor_restaurant_id)&.name
      end

      def brand_short_name(name)
        name.to_s.split(/\s+[|\-–—]\s+/).first
      end
    end
  end
end
