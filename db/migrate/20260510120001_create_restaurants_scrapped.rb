class CreateRestaurantsScrapped < ActiveRecord::Migration[7.0]
  def change
    create_table :restaurants_scrapped do |t|
      t.belongs_to :restaurant, null: false, foreign_key: true

      t.bigint  :swiggy_restaurant_id
      t.string  :input_name
      t.string  :name
      t.string  :city
      t.string  :locality
      t.string  :area
      t.text    :address
      t.string  :cost_for_two_raw
      t.integer :cost_for_two
      t.text    :cuisines, array: true, default: []
      t.decimal :avg_rating, precision: 3, scale: 2
      t.string  :total_ratings_raw
      t.integer :total_ratings
      t.decimal :google_rating, precision: 3, scale: 2
      t.integer :google_rating_count
      t.boolean :pure_veg
      t.boolean :is_open
      t.datetime :next_close_time, precision: 0
      t.integer :delivery_time_min
      t.integer :delivery_time_max
      t.decimal :distance_km, precision: 6, scale: 2
      t.bigint  :parent_id
      t.boolean :is_chain
      t.string  :discount_header
      t.text    :offers, array: true, default: []
      t.text    :image_url
      t.text    :swiggy_url
      t.decimal :swiggy_lat, precision: 10, scale: 7
      t.decimal :swiggy_lng, precision: 10, scale: 7

      t.jsonb :menu
      t.jsonb :google_reviews

      t.datetime :scrapped_at, precision: 0, null: false
      t.date     :scrapped_at_date, null: false

      t.timestamps
    end

    add_index :restaurants_scrapped,
              [:restaurant_id, :scrapped_at_date],
              unique: true,
              name:   "index_rest_scrap_on_restaurant_and_date"

    add_index :restaurants_scrapped, :scrapped_at_date,
              name: "index_rest_scrap_on_scrapped_at_date"

    add_index :restaurants_scrapped,
              [:swiggy_restaurant_id, :scrapped_at_date],
              unique: true,
              where:  "swiggy_restaurant_id IS NOT NULL",
              name:   "index_rest_scrap_on_swiggy_id_and_date"
  end
end
