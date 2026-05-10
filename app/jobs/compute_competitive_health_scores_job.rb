class ComputeCompetitiveHealthScoresJob < ApplicationJob
  queue_as :default

  def perform(date_iso = nil, competitor_set_id: nil)
    date = date_iso ? Date.parse(date_iso) : Date.current
    if competitor_set_id
      Score::CompetitiveHealth.compute_for_set(competitor_set_id: competitor_set_id, date: date)
    else
      Score::CompetitiveHealth.compute_all(date: date)
    end
  end
end
