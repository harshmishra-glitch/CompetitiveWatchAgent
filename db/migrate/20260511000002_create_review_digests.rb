class CreateReviewDigests < ActiveRecord::Migration[7.0]
  def change
    create_table :review_digests do |t|
      t.belongs_to :pilot_restaurant, null: false, foreign_key: true
      t.belongs_to :competitor_set, foreign_key: true

      t.date     :digest_date, null: false
      t.string   :status, default: "draft", null: false
      t.string   :model_version
      t.jsonb    :prompt_context
      t.jsonb    :reviews_payload, null: false, default: []
      t.datetime :generated_at, precision: 0

      t.timestamps
    end

    add_index :review_digests,
              [:pilot_restaurant_id, :competitor_set_id, :digest_date],
              unique: true,
              name: "index_review_digests_on_pilot_set_and_date"
  end
end
