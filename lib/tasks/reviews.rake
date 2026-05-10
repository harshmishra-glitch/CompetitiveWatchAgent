namespace :reviews do
  desc "Backfill restaurants_scrapped.google_rating from seed + scraped reviews. Usage: rake reviews:backfill_google_rating[restaurant_id]"
  task :backfill_google_rating, %i[restaurant_id] => :environment do |_, args|
    stats = Reviews::GoogleRatingBackfiller.call(restaurant_id: args[:restaurant_id]&.to_i)
    puts "[reviews:backfill_google_rating] #{stats.inspect}"
  end
end
