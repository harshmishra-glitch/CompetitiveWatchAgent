class CreateSerpOrganicResults < ActiveRecord::Migration[7.0]
  def change
    create_table :serp_organic_results do |t|
      t.belongs_to :google_serp_scrape, null: false, foreign_key: true,
                   index: { name: "index_serp_results_on_serp_scrape_id" }
      t.belongs_to :restaurant, null: false, foreign_key: true,
                   index: { name: "index_serp_results_on_restaurant_id" }

      t.integer :position
      t.string  :result_type                # 'organic' | 'paid' | 'reel' | 'maps'
      t.string  :title
      t.text    :url
      t.text    :displayed_url
      t.text    :description
      t.string  :channel_name

      t.decimal :average_rating, precision: 3, scale: 2
      t.integer :number_of_reviews
      t.string  :followers_amount
      t.string  :views
      t.string  :last_updated_raw

      t.text    :emphasized_keywords, array: true, default: []
      t.jsonb   :site_links
      t.jsonb   :product_info
      t.jsonb   :raw

      t.date    :scrapped_at_date, null: false

      t.timestamps
    end

    add_index :serp_organic_results,
              [:restaurant_id, :scrapped_at_date, :position],
              name: "index_serp_results_on_restaurant_date_position"

    add_index :serp_organic_results, :result_type,
              name: "index_serp_results_on_result_type"
  end
end
