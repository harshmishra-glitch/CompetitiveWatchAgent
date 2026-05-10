class CreateRestaurants < ActiveRecord::Migration[7.0]
  def change
    create_table :restaurants do |t|
      t.string  :name, null: false
      t.text    :maps_url
      t.decimal :rating, precision: 3, scale: 2
      t.integer :review_count

      t.timestamps
    end

    add_index :restaurants, :name
  end
end
