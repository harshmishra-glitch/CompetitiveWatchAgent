class CreatePilotRestaurants < ActiveRecord::Migration[7.0]
  def change
    create_table :pilot_restaurants do |t|
      t.belongs_to :restaurant, null: false, foreign_key: true,
                   index: { unique: true, name: "index_pilot_restaurants_on_restaurant_id" }

      t.boolean  :active, default: true, null: false
      t.datetime :set_at, precision: 0, null: false

      t.timestamps
    end
  end
end
