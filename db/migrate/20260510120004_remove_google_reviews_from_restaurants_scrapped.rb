class RemoveGoogleReviewsFromRestaurantsScrapped < ActiveRecord::Migration[7.0]
  def change
    remove_column :restaurants_scrapped, :google_reviews, :jsonb
  end
end
