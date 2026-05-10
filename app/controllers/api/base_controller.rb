module Api
  class BaseController < ApplicationController
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :render_invalid
    rescue_from ActionController::ParameterMissing, with: :render_bad_request

    private

    def current_pilot_restaurant
      @current_pilot_restaurant ||= begin
        id = request.headers["X-Pilot-Restaurant-Id"] || params[:pilot_restaurant_id]
        if id.present?
          PilotRestaurant.find(id)
        else
          PilotRestaurant.active.order(set_at: :desc).first
        end
      end
    end

    def require_pilot!
      return if current_pilot_restaurant
      render_error(:not_found, "no_pilot_restaurant", "No active pilot restaurant. Set one via POST /api/pilot_restaurants.")
    end

    def page
      [params[:page].to_i, 1].max
    end

    def per_page
      [[params[:per_page].to_i, 25].max, 200].min
    end

    def parse_date(value, default:)
      return default if value.blank?
      Date.parse(value.to_s)
    rescue ArgumentError
      default
    end

    def parse_since(value, default_days: 30)
      return default_days.days.ago.to_date if value.blank?
      m = value.to_s.match(/\A(\d+)([dDwWmM])\z/)
      if m
        unit = { "d" => :days, "w" => :weeks, "m" => :months }[m[2].downcase]
        return m[1].to_i.public_send(unit).ago.to_date
      end
      Date.parse(value.to_s)
    rescue ArgumentError
      default_days.days.ago.to_date
    end

    def render_error(status, code, message, detail = nil)
      payload = { error: { code: code, message: message } }
      payload[:error][:detail] = detail if detail
      render json: payload, status: status
    end

    def render_not_found(exc)
      render_error(:not_found, "not_found", exc.message)
    end

    def render_invalid(exc)
      render_error(:unprocessable_entity, "validation_failed", exc.message,
                   exc.record&.errors&.to_hash)
    end

    def render_bad_request(exc)
      render_error(:bad_request, "bad_request", exc.message)
    end
  end
end
