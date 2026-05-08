class CreateRestaurantGoogleReviews < ActiveRecord::Migration[7.0]
  def change
    create_table :restaurant_google_reviews do |t|
      t.references :restaurant, null: false, foreign_key: true, type: :bigint

      t.string  :restaurant_name
      t.string  :phone
      t.text    :address

      t.decimal :latitude,  precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7

      t.string  :place_type
      t.text    :website

      t.string  :review_id, null: false
      t.string  :place_name

      t.string  :reviewer_name
      t.string  :reviewer_id
      t.boolean :local_guide

      t.integer :rating
      t.text    :review_text
      t.integer :likes

      t.string   :date_raw
      t.datetime :review_posted_at, precision: 0

      t.jsonb   :review_attributes

      t.datetime :scrapped_at, precision: 0, null: false
      t.date     :scrapped_at_date,           null: false

      t.timestamps
    end

    add_index :restaurant_google_reviews, [:restaurant_id, :scrapped_at_date],
              name: "index_reviews_on_restaurant_and_scrape_date"
    add_index :restaurant_google_reviews, [:review_id, :scrapped_at_date],
              unique: true, name: "index_reviews_on_review_id_and_scrape_date"
    add_index :restaurant_google_reviews, [:restaurant_id, :review_posted_at],
              name: "index_reviews_on_restaurant_and_posted_at"
  end
end
