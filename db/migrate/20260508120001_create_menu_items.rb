class CreateMenuItems < ActiveRecord::Migration[7.0]
  def change
    create_table :menu_items do |t|
      t.references :restaurant, null: false, foreign_key: true, type: :bigint

      t.string  :category
      t.string  :subcategory
      t.string  :name, null: false

      t.string  :price_raw
      t.integer :price

      t.jsonb   :variants

      t.text    :description
      t.boolean :veg

      t.decimal :rating, precision: 3, scale: 2
      t.integer :rating_count

      t.boolean :bestseller, default: false, null: false
      t.string  :availability

      t.datetime :scrapped_at, precision: 0, null: false
      t.date     :scrapped_at_date,           null: false

      t.timestamps
    end

    add_index :menu_items, [:restaurant_id, :scrapped_at_date]
    add_index :menu_items, [:restaurant_id, :name, :scrapped_at_date],
              name: "index_menu_items_on_restaurant_name_and_scrape_date"
  end
end
