namespace :score do
  desc "Compute competitive health scores for all active sets on one date. Usage: rake score:compute[YYYY-MM-DD]"
  task :compute, %i[date] => :environment do |_, args|
    date = args[:date].present? ? Date.parse(args[:date]) : Date.current
    Score::CompetitiveHealth.compute_all(date: date)
    rows = CompetitiveHealthScore.where(score_date: date).count
    puts "[score:compute] date=#{date} rows_written=#{rows}"
  end

  desc "Backfill competitive health scores for a date range. Usage: rake score:backfill[YYYY-MM-DD,YYYY-MM-DD]"
  task :backfill, %i[from to] => :environment do |_, args|
    abort "usage: rake score:backfill[YYYY-MM-DD,YYYY-MM-DD]" unless args[:from] && args[:to]

    from = Date.parse(args[:from])
    to   = Date.parse(args[:to])
    (from..to).each do |d|
      Score::CompetitiveHealth.compute_all(date: d)
      rows = CompetitiveHealthScore.where(score_date: d).count
      puts "[score:backfill] #{d} rows=#{rows}"
    end
  end

  desc "Compute scores for one specific competitor set on one date. Usage: rake score:set[set_id,YYYY-MM-DD]"
  task :set, %i[set_id date] => :environment do |_, args|
    abort "usage: rake score:set[set_id,YYYY-MM-DD]" if args[:set_id].nil?
    date = args[:date].present? ? Date.parse(args[:date]) : Date.current
    Score::CompetitiveHealth.compute_for_set(competitor_set_id: args[:set_id].to_i, date: date)
    puts "[score:set] set=#{args[:set_id]} date=#{date} done"
  end
end
