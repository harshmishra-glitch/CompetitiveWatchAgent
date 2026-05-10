class CreateMenuItems < ActiveRecord::Migration[7.0]
  def change
    create_table :menu_items do |t|
      t.belongs_to :restaurants_scrapped,
                   null: false,
                   foreign_key: { to_table: :restaurants_scrapped },
                   index: { name: "index_menu_items_on_restaurants_scrapped_id" }

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
      t.boolean :bestseller, null: false, default: false
      t.string  :availability

      t.timestamps
    end

    add_index :menu_items,
              [:restaurants_scrapped_id, :name],
              name: "index_menu_items_on_scrap_id_and_name"
  end
end
