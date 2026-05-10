class RefreshThreatAssessmentsJob < ApplicationJob
  queue_as :default

  def perform(pilot_restaurant_id)
    Threat::Analyzer.call_for_set(pilot_restaurant_id: pilot_restaurant_id)
  end
end
