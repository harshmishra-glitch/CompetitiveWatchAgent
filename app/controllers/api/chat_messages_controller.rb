module Api
  class ChatMessagesController < BaseController
    # GET /api/chat_sessions/:chat_session_id/messages?include=trace
    def index
      session = ChatSession.find(params[:chat_session_id])
      messages = session.chat_messages.order(:created_at)
      render json: { messages: messages.map { |m| message_payload(m) } }
    end

    # POST /api/chat_sessions/:chat_session_id/messages
    # Body: { content }
    # Query: ?include=trace  -> include tool_calls + tool_results in the response
    def create
      content = params.require(:content)
      result = Chatbot::Agent.respond(
        chat_session_id: params[:chat_session_id],
        user_content:    content
      )
      render json: {
        user_message:      message_payload(result[:user_message]),
        assistant_message: message_payload(result[:assistant_message])
      }, status: :created
    rescue Llm::OpenaiClient::QuotaExceeded => e
      render_error(:too_many_requests, "llm_quota_exceeded",
                   "OpenAI quota exceeded. Add billing or top up credits, then retry.",
                   e.message)
    rescue Llm::OpenaiClient::RateLimited => e
      render_error(:too_many_requests, "llm_rate_limited",
                   "Hit OpenAI's rate limit. Slow down and retry shortly.",
                   e.message)
    rescue Llm::OpenaiClient::AuthError => e
      render_error(:bad_gateway, "llm_auth_error",
                   "OpenAI rejected the API key. Check OPENAI_API_KEY.",
                   e.message)
    rescue Llm::OpenaiClient::ProviderError => e
      render_error(:bad_gateway, "llm_provider_error",
                   "OpenAI is having issues. Try again in a moment.",
                   e.message)
    rescue Llm::OpenaiClient::BadRequest => e
      render_error(:bad_request, "llm_bad_request", e.message)
    rescue Llm::OpenaiClient::Error => e
      render_error(:bad_gateway, "llm_error", e.message)
    end

    private

    def include_trace?
      params[:include].to_s.split(",").include?("trace")
    end

    def message_payload(m)
      base = {
        id:            m.id,
        role:          m.role,
        content:       m.content,
        citations:     m.citations,
        model_version: m.model_version,
        created_at:    m.created_at
      }
      base.merge!(tool_calls: m.tool_calls, tool_results: m.tool_results) if include_trace?
      base
    end
  end
end
