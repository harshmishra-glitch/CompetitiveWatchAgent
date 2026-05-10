class HealthController < ActionController::API
  # GET /health
  # Liveness + readiness probe. 200 if Rails is up and DB is reachable.
  def show
    db_ok = ActiveRecord::Base.connection.execute("SELECT 1").any?
    render json: {
      status: "ok",
      db:     db_ok,
      time:   Time.current.iso8601
    }
  rescue => e
    render json: {
      status: "down",
      error:  e.class.name,
      time:   Time.current.iso8601
    }, status: :service_unavailable
  end
end
