class CreateGoogleReviewScrapes < ActiveRecord::Migration[7.0]
  def change
    create_table :google_review_scrapes do |t|
      t.belongs_to :restaurant, null: false, foreign_key: true

      t.jsonb    :reviews
      t.integer  :review_count
      t.datetime :scrapped_at, precision: 0, null: false
      t.date     :scrapped_at_date, null: false

      t.timestamps
    end

    add_index :google_review_scrapes,
              [:restaurant_id, :scrapped_at_date],
              unique: true,
              name:   "index_grs_on_restaurant_and_date"

    add_index :google_review_scrapes, :scrapped_at_date,
              name: "index_grs_on_scrapped_at_date"
  end
end
