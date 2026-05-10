class CreateInstagramScrapes < ActiveRecord::Migration[7.0]
  def change
    create_table :instagram_scrapes do |t|
      t.belongs_to :restaurant, null: false, foreign_key: true

      t.string  :handle
      t.integer :profile_post_count, default: 0, null: false
      t.integer :hashtag_post_count, default: 0, null: false
      t.jsonb   :payload

      t.datetime :scrapped_at, precision: 0, null: false
      t.date     :scrapped_at_date, null: false

      t.timestamps
    end

    add_index :instagram_scrapes,
              [:restaurant_id, :scrapped_at_date],
              unique: true,
              name:   "index_ig_scrapes_on_restaurant_and_date"

    add_index :instagram_scrapes, :scrapped_at_date,
              name: "index_ig_scrapes_on_scrapped_at_date"
  end
end
