module Api
  class ChatSessionsController < BaseController
    # GET /api/chat_sessions?pilot_restaurant_id=
    def index
      pilot_id = params[:pilot_restaurant_id].presence || current_pilot_restaurant&.id
      return render_error(:bad_request, "missing_pilot", "pilot_restaurant_id required") if pilot_id.nil?

      sessions = ChatSession
                   .where(pilot_restaurant_id: pilot_id)
                   .order(last_message_at: :desc, started_at: :desc)
                   .limit(per_page)

      render json: { chat_sessions: sessions.map { |s| session_payload(s) } }
    end

    # GET /api/chat_sessions/:id
    def show
      session = ChatSession.find(params[:id])
      render json: { chat_session: session_payload(session) }
    end

    # POST /api/chat_sessions
    # Body: { pilot_restaurant_id, title? }
    def create
      pilot_id = params.require(:pilot_restaurant_id)
      pilot    = PilotRestaurant.find(pilot_id)

      session = ChatSession.create!(
        pilot_restaurant_id: pilot.id,
        title:               params[:title],
        started_at:          Time.current
      )
      render json: { chat_session: session_payload(session) }, status: :created
    end

    private

    def session_payload(s)
      { id: s.id, pilot_restaurant_id: s.pilot_restaurant_id,
        title: s.title, started_at: s.started_at,
        last_message_at: s.last_message_at, message_count: s.message_count }
    end
  end
end
