class CreateCompetitorSets < ActiveRecord::Migration[7.0]
  def change
    create_table :competitor_sets do |t|
      t.belongs_to :pilot_restaurant, null: false, foreign_key: true,
                   index: { name: "index_competitor_sets_on_pilot_restaurant_id" }

      t.string  :name
      t.boolean :active, default: true, null: false

      t.timestamps
    end
  end
end
