class CreateThreatAssessments < ActiveRecord::Migration[7.0]
  def change
    create_table :threat_assessments do |t|
      t.belongs_to :pilot_restaurant, null: false, foreign_key: true,
                   index: { name: "index_threat_on_pilot_restaurant_id" }
      t.belongs_to :competitor_restaurant, null: false,
                   foreign_key: { to_table: :restaurants },
                   index: { name: "index_threat_on_competitor_restaurant_id" }

      t.decimal :segment_overlap,        precision: 5, scale: 4
      t.decimal :price_band_overlap,     precision: 5, scale: 4
      t.decimal :neighbourhood_overlap,  precision: 5, scale: 4
      t.decimal :cuisine_overlap,        precision: 5, scale: 4
      t.decimal :total_threat,           precision: 5, scale: 4

      t.text    :rationale
      t.jsonb   :breakdown

      t.datetime :computed_at, precision: 0, null: false

      t.timestamps
    end

    add_index :threat_assessments,
              [:pilot_restaurant_id, :competitor_restaurant_id],
              unique: true,
              name:   "index_threat_on_pilot_and_competitor"
  end
end
