module Chatbot
  # Tool-use loop. Given a chat session and a new user message, runs OpenAI
  # function calling until the model produces a final text answer, then
  # persists user + assistant messages with citations and tool traces.
  class Agent
    MAX_TOOL_ITERATIONS = 6

    def self.respond(chat_session_id:, user_content:, llm_client: Llm::OpenaiClient.default)
      new(chat_session_id: chat_session_id, user_content: user_content, llm_client: llm_client).call
    end

    def initialize(chat_session_id:, user_content:, llm_client:)
      @session = ChatSession.find(chat_session_id)
      @pilot   = @session.pilot_restaurant
      @user_content = user_content.to_s
      @llm     = llm_client
    end

    def call
      @user_message = @session.chat_messages.create!(role: "user", content: @user_content)

      messages = build_initial_messages
      tool_trace = []
      assistant_message = nil

      begin
        MAX_TOOL_ITERATIONS.times do
          response = @llm.chat(
            model:       Llm::Models.chat,
            messages:    messages,
            temperature: 0.2,
            tools:       Tools.schemas,
            tool_choice: "auto"
          )

          # Append the assistant message into the running transcript so subsequent
          # tool messages reference its tool_call_ids.
          messages << response

          tool_calls = response["tool_calls"] || []
          if tool_calls.empty?
            assistant_message = persist_assistant(response, tool_trace)
            break
          end

          tool_calls.each do |tc|
            name = tc.dig("function", "name")
            args = parse_args(tc.dig("function", "arguments"))
            result = Tools.dispatch(name, args, @pilot)
            tool_trace << { tool: name, args: args, result_preview: preview(result) }
            messages << {
              role:         "tool",
              tool_call_id: tc["id"],
              content:      result.to_json
            }
          end
        end
      rescue Llm::OpenaiClient::Error => e
        # Roll back the user message so the transcript stays clean and the FE can
        # safely retry the same content.
        @user_message.destroy
        raise e
      end

      assistant_message ||= persist_assistant({ "content" => "I couldn't complete the analysis in time. Try narrowing the question." }, tool_trace)

      @session.update!(
        last_message_at: Time.current,
        message_count:   @session.chat_messages.count
      )

      { user_message: @user_message, assistant_message: assistant_message }
    end

    private

    def build_initial_messages
      base = [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "system", content: pilot_context_block }
      ]
      history = @session.chat_messages
                        .where.not(id: @user_message.id)
                        .order(:created_at)
                        .last(20)
                        .map { |m| { role: m.role, content: m.content.to_s } }
      base + history + [{ role: "user", content: @user_content }]
    end

    def pilot_context_block
      return "No pilot restaurant set yet." if @pilot.nil?
      r = @pilot.restaurant
      set = @pilot.active_competitor_set
      members = set ? set.active_members.includes(:restaurant) : []

      <<~CTX.strip
        Pilot restaurant: #{r.name} (id=#{r.id}, rating=#{r.rating}, reviews=#{r.review_count}).
        Active competitor set id=#{set&.id}. Tracked competitors:
        #{members.map { |m| "- #{m.restaurant.name} (id=#{m.restaurant_id})" }.join("\n")}
      CTX
    end

    def parse_args(raw)
      return {} if raw.nil? || raw.to_s.strip.empty?
      JSON.parse(raw)
    rescue JSON::ParserError
      {}
    end

    def persist_assistant(message, tool_trace)
      content = message["content"].to_s
      citations = extract_citations(tool_trace)

      @session.chat_messages.create!(
        role:          "assistant",
        content:       content,
        tool_calls:    tool_trace.map { |t| t.slice(:tool, :args) },
        tool_results:  tool_trace.map { |t| t.slice(:tool, :result_preview) },
        citations:     citations,
        model_version: Llm::Models.chat
      )
    end

    def extract_citations(tool_trace)
      ids = tool_trace.flat_map { |t|
        result = t[:result_preview]
        next [] if result.nil?
        scan_ids(result)
      }.compact.uniq
      { restaurant_ids: ids }
    end

    def scan_ids(value)
      case value
      when Hash  then value.flat_map { |k, v| k.to_s.match?(/restaurant_id\z/) ? [v] : scan_ids(v) }
      when Array then value.flat_map { |v| scan_ids(v) }
      else            []
      end
    end

    def preview(result)
      str = result.is_a?(String) ? result : result.to_json
      return result if str.bytesize <= 4_000
      JSON.parse(str[0, 3_900] + "}") rescue { truncated: true }
    end

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are CLINK's Competitive Watch chatbot for restaurant owners.
      Your job: answer questions about the pilot restaurant and its competitors.

      Rules of engagement:
      - Always ground numerical claims in tool calls. Do not invent prices, ratings, or counts.
      - Prefer the most direct tool. Don't fan out unless the question genuinely requires it.
      - Lead with the answer in 1-2 sentences. Only add depth if relevant.
      - Call out specific numbers, dates, and restaurant names.
      - When asked about "my restaurant", "us", "we", that means the pilot.
      - When in doubt about ids, call search_restaurants first.
      - End your answer with a short "Suggested next step:" line when there's a clear action.
      - No markdown headers or tables unless the user asked for them.
    PROMPT
  end
end
