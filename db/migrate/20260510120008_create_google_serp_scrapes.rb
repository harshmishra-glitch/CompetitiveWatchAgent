class CreateGoogleSerpScrapes < ActiveRecord::Migration[7.0]
  def change
    create_table :google_serp_scrapes do |t|
      t.belongs_to :restaurant, null: false, foreign_key: true

      t.string  :search_term
      t.text    :search_url
      t.integer :results_total
      t.boolean :has_next_page, default: false, null: false
      t.string  :provider_code
      t.jsonb   :payload

      t.datetime :scrapped_at, precision: 0, null: false
      t.date     :scrapped_at_date, null: false

      t.timestamps
    end

    add_index :google_serp_scrapes,
              [:restaurant_id, :scrapped_at_date],
              unique: true,
              name:   "index_serp_scrapes_on_restaurant_and_date"

    add_index :google_serp_scrapes, :scrapped_at_date,
              name: "index_serp_scrapes_on_scrapped_at_date"
  end
end
