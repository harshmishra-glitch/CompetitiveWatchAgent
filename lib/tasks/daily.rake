namespace :daily do
  desc "Daily pipeline: score every active set, then generate digest + threats per pilot. Usage: rake daily:run[YYYY-MM-DD]"
  task :run, %i[date] => :environment do |_, args|
    date = args[:date].present? ? Date.parse(args[:date]) : Date.current
    puts "[daily:run] start date=#{date}"

    Score::CompetitiveHealth.compute_all(date: date)
    puts "[daily:run] scores written for #{date}"

    pilots = PilotRestaurant.active.find_each.to_a
    puts "[daily:run] pilots=#{pilots.size}"

    pilots.each do |pilot|
      Digest::Generator.call(pilot_restaurant_id: pilot.id, date: date)
      Threat::Analyzer.call_for_set(pilot_restaurant_id: pilot.id)
      puts "[daily:run] pilot=#{pilot.id} done"
    rescue => e
      puts "[daily:run] pilot=#{pilot.id} ERROR #{e.class}: #{e.message}"
    end

    puts "[daily:run] complete"
  end
end
