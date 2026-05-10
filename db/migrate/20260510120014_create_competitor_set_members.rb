class CreateCompetitorSetMembers < ActiveRecord::Migration[7.0]
  def change
    create_table :competitor_set_members do |t|
      t.belongs_to :competitor_set, null: false, foreign_key: true,
                   index: { name: "index_csm_on_competitor_set_id" }
      t.belongs_to :restaurant, null: false, foreign_key: true,
                   index: { name: "index_csm_on_restaurant_id" }

      t.string   :source, null: false, default: "suggested"  # 'suggested' | 'manual'
      t.datetime :added_at, precision: 0, null: false
      t.datetime :removed_at, precision: 0

      t.timestamps
    end

    add_index :competitor_set_members,
              [:competitor_set_id, :restaurant_id],
              unique: true,
              name:   "index_csm_on_set_and_restaurant"
  end
end
