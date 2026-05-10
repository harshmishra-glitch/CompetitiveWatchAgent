namespace :llm do
  desc "Generate today's daily digest. Usage: rake llm:digest[pilot_id,YYYY-MM-DD]"
  task :digest, %i[pilot_id date] => :environment do |_, args|
    pilot_id = args[:pilot_id] || PilotRestaurant.active.order(set_at: :desc).first&.id
    abort "no pilot_restaurant_id given and no active pilot found" if pilot_id.nil?

    date = args[:date].present? ? Date.parse(args[:date]) : Date.current
    digest = Digest::Generator.call(pilot_restaurant_id: pilot_id, date: date)
    puts "[digest] pilot=#{pilot_id} date=#{date} cards=#{digest.digest_competitor_cards.count} quiet_day=#{digest.quiet_day}"
  end

  desc "Refresh threat assessments for the pilot's active competitor set. Usage: rake llm:threats[pilot_id]"
  task :threats, %i[pilot_id] => :environment do |_, args|
    pilot_id = args[:pilot_id] || PilotRestaurant.active.order(set_at: :desc).first&.id
    abort "no pilot_restaurant_id given and no active pilot found" if pilot_id.nil?

    rows = Threat::Analyzer.call_for_set(pilot_restaurant_id: pilot_id)
    puts "[threats] pilot=#{pilot_id} computed=#{rows.size}"
  end

  desc "Run digest + threats for every active pilot"
  task all: :environment do
    PilotRestaurant.active.find_each do |pilot|
      Digest::Generator.call(pilot_restaurant_id: pilot.id, date: Date.current)
      Threat::Analyzer.call_for_set(pilot_restaurant_id: pilot.id)
      puts "[llm:all] pilot=#{pilot.id} done"
    end
  end
end
