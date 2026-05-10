namespace :events do
  desc "Detect events for every restaurant on one date. Usage: rake events:detect[YYYY-MM-DD]"
  task :detect, %i[date] => :environment do |_, args|
    date = args[:date].present? ? Date.parse(args[:date]) : Date.current
    ids  = restaurant_ids
    counts = Events::Detector.persist_range(restaurant_ids: ids, from: date, to: date)
    puts "[events:detect] date=#{date} restaurants=#{ids.size} #{counts.inspect}"
  end

  desc "Backfill events for a date range. Usage: rake events:backfill[YYYY-MM-DD,YYYY-MM-DD]"
  task :backfill, %i[from to] => :environment do |_, args|
    abort "usage: rake events:backfill[YYYY-MM-DD,YYYY-MM-DD]" unless args[:from] && args[:to]
    from = Date.parse(args[:from])
    to   = Date.parse(args[:to])
    ids  = restaurant_ids
    counts = Events::Detector.persist_range(restaurant_ids: ids, from: from, to: to)
    puts "[events:backfill] #{from}..#{to} restaurants=#{ids.size} #{counts.inspect}"
  end

  desc "Detect events for one restaurant on one date. Usage: rake events:one[restaurant_id,YYYY-MM-DD]"
  task :one, %i[restaurant_id date] => :environment do |_, args|
    abort "usage: rake events:one[restaurant_id,YYYY-MM-DD]" if args[:restaurant_id].nil?
    date = args[:date].present? ? Date.parse(args[:date]) : Date.current
    counts = Events::Detector.persist_for(restaurant_id: args[:restaurant_id].to_i, date: date)
    puts "[events:one] restaurant=#{args[:restaurant_id]} date=#{date} #{counts.inspect}"
  end

  def restaurant_ids
    Restaurant.joins(:scrapes).distinct.pluck(:id)
  end
end
