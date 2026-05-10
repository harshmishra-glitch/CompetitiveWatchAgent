class BootstrapPilotJob < ApplicationJob
  queue_as :default

  # Runs the LLM-heavy portion of "Set up my dashboard":
  #   - threat assessments for every competitor in the active set
  #   - daily digest for `date` (default today)
  #
  # Scoring (no LLM) runs inline in the controller before this job is enqueued,
  # so the leaderboard endpoint returns useful data the moment the request
  # completes. This job is the slower part the FE polls for.
  #
  # Failures in any step are logged but don't crash the job — partial bootstrap
  # is better than no bootstrap.
  def perform(pilot_restaurant_id, date_iso = nil)
    pilot = PilotRestaurant.find(pilot_restaurant_id)
    return unless pilot.active_competitor_set

    date = date_iso ? Date.parse(date_iso) : Date.current

    safe_step("threats") do
      Threat::Analyzer.call_for_set(pilot_restaurant_id: pilot.id)
    end

    safe_step("digest") do
      Digest::Generator.call(pilot_restaurant_id: pilot.id, date: date)
    end
  end

  private

  def safe_step(name)
    yield
    Rails.logger.info("[bootstrap_pilot] step=#{name} status=ok")
  rescue => e
    Rails.logger.error("[bootstrap_pilot] step=#{name} status=fail #{e.class}: #{e.message}")
  end
end
