class GenerateDailyDigestJob < ApplicationJob
  queue_as :default

  def perform(pilot_restaurant_id, date_iso = nil)
    date = date_iso ? Date.parse(date_iso) : Date.current
    Digest::Generator.call(pilot_restaurant_id: pilot_restaurant_id, date: date)
  end
end
