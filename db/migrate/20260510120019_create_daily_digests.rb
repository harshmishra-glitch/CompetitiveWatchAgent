class CreateDailyDigests < ActiveRecord::Migration[7.0]
  def change
    create_table :daily_digests do |t|
      t.belongs_to :pilot_restaurant, null: false, foreign_key: true,
                   index: { name: "index_daily_digests_on_pilot_restaurant_id" }

      t.date    :digest_date, null: false
      t.text    :summary, null: false
      t.string  :status, default: "draft", null: false   # 'draft' | 'published'
      t.boolean :quiet_day, default: false, null: false

      t.string   :model_version
      t.jsonb    :prompt_context
      t.datetime :generated_at, precision: 0

      t.timestamps
    end

    add_index :daily_digests,
              [:pilot_restaurant_id, :digest_date],
              unique: true,
              name:   "index_daily_digests_on_pilot_and_date"
  end
end
