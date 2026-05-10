class AddIdentityColumnsToRestaurants < ActiveRecord::Migration[7.0]
  def change
    change_table :restaurants do |t|
      t.decimal :lat, precision: 10, scale: 7
      t.decimal :lng, precision: 10, scale: 7
      t.text    :primary_cuisines, array: true, default: []
      t.string  :price_band
      t.integer :cost_for_two
    end

    add_index :restaurants, [:lat, :lng], name: "index_restaurants_on_lat_lng"
    add_index :restaurants, :primary_cuisines, using: :gin,
              name: "index_restaurants_on_primary_cuisines"
    add_index :restaurants, :price_band
  end
end
