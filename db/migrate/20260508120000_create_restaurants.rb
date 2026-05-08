class CreateRestaurants < ActiveRecord::Migration[7.0]
  def change
    create_table :restaurants do |t|
      t.bigint  :swiggy_restaurant_id, null: false
      t.string  :input_name
      t.string  :name, null: false
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

      t.jsonb   :menu
      t.jsonb   :google_reviews

      t.datetime :scrapped_at, precision: 0, null: false
      t.date     :scrapped_at_date,           null: false

      t.timestamps
    end

    add_index :restaurants, [:swiggy_restaurant_id, :scrapped_at_date],
              unique: true, name: "index_restaurants_on_swiggy_id_and_scrape_date"
    add_index :restaurants, :scrapped_at_date
    add_index :restaurants, [:city, :locality]
    add_index :restaurants, :avg_rating
  end
end
