class CreateDigestCompetitorCards < ActiveRecord::Migration[7.0]
  def change
    create_table :digest_competitor_cards do |t|
      t.belongs_to :daily_digest, null: false, foreign_key: true,
                   index: { name: "index_digest_cards_on_daily_digest_id" }
      t.belongs_to :competitor_restaurant, null: false,
                   foreign_key: { to_table: :restaurants },
                   index: { name: "index_digest_cards_on_competitor_restaurant_id" }

      t.text   :change_summary, null: false
      t.text   :why_it_matters
      t.string :recommendation, null: false   # 'defend' | 'watch' | 'ignore'
      t.text   :rationale

      t.bigint  :source_event_ids, array: true, default: []
      t.decimal :priority, precision: 5, scale: 2, default: 0, null: false

      t.timestamps
    end

    add_index :digest_competitor_cards,
              [:daily_digest_id, :competitor_restaurant_id],
              unique: true,
              name:   "index_digest_cards_on_digest_and_competitor"

    add_index :digest_competitor_cards, :recommendation,
              name: "index_digest_cards_on_recommendation"
  end
end
