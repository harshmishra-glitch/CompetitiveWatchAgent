class CreateMenuChangeEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :menu_change_events do |t|
      t.belongs_to :restaurant, null: false, foreign_key: true,
                   index: { name: "index_menu_change_events_on_restaurant_id" }

      t.string  :menu_item_name, null: false
      t.string  :event_type, null: false   # 'added' | 'removed' | 'price_increased' | 'price_decreased' | 'renamed'
      t.string  :category
      t.string  :subcategory

      t.integer :prev_price
      t.integer :new_price
      t.integer :price_delta

      t.string  :prev_name
      t.string  :new_name

      t.date    :prev_scrapped_at_date
      t.date    :scrapped_at_date, null: false

      t.jsonb   :before
      t.jsonb   :after

      t.timestamps
    end

    add_index :menu_change_events,
              [:restaurant_id, :scrapped_at_date],
              name: "index_menu_change_events_on_restaurant_and_date"

    add_index :menu_change_events, :event_type,
              name: "index_menu_change_events_on_event_type"
  end
end
