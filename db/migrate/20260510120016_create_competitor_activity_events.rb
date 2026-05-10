class CreateCompetitorActivityEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :competitor_activity_events do |t|
      t.belongs_to :restaurant, null: false, foreign_key: true,
                   index: { name: "index_activity_events_on_restaurant_id" }

      # 'menu_added' | 'menu_removed' | 'price_changed' | 'rating_shift'
      # | 'offer_added' | 'offer_removed' | 'social_post' | 'new_location'
      # | 'sentiment_shift' | 'review_surge' | 'serp_position_change'
      t.string :event_type, null: false

      t.text   :summary
      t.string :detected_from               # 'restaurants_scrapped' | 'menu_items'
                                            # | 'google_review_scrapes' | 'instagram_posts'
                                            # | 'serp_organic_results'
      t.bigint :source_record_id
      t.bigint :menu_change_event_id

      t.jsonb  :before
      t.jsonb  :after

      t.decimal :significance, precision: 5, scale: 2, default: 0, null: false

      t.date     :occurred_on, null: false
      t.datetime :detected_at, precision: 0, null: false

      t.timestamps
    end

    add_index :competitor_activity_events,
              [:restaurant_id, :occurred_on],
              name: "index_activity_events_on_restaurant_and_date"

    add_index :competitor_activity_events, :event_type,
              name: "index_activity_events_on_event_type"

    add_index :competitor_activity_events,
              [:occurred_on, :significance],
              name: "index_activity_events_on_date_and_significance"
  end
end
