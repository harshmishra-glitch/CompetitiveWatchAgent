class CreateCompetitiveHealthScores < ActiveRecord::Migration[7.0]
  def change
    create_table :competitive_health_scores do |t|
      t.belongs_to :restaurant, null: false, foreign_key: true,
                   index: { name: "index_chs_on_restaurant_id" }
      t.belongs_to :competitor_set, null: true, foreign_key: true,
                   index: { name: "index_chs_on_competitor_set_id" }

      t.date :score_date, null: false

      t.decimal :total_score,        precision: 6, scale: 2
      t.decimal :rating_trajectory,  precision: 6, scale: 2
      t.decimal :review_velocity,    precision: 6, scale: 2
      t.decimal :menu_activity,      precision: 6, scale: 2
      t.decimal :social_mentions,    precision: 6, scale: 2
      t.decimal :estimated_demand,   precision: 6, scale: 2
      t.decimal :serp_visibility,    precision: 6, scale: 2

      t.integer :rank_in_set
      t.decimal :score_delta_7d, precision: 6, scale: 2
      t.text    :headline_signal

      t.jsonb :breakdown          # full feature vector for debugging / chatbot context

      t.timestamps
    end

    add_index :competitive_health_scores,
              [:restaurant_id, :score_date],
              unique: true,
              name:   "index_chs_on_restaurant_and_date"

    add_index :competitive_health_scores,
              [:competitor_set_id, :score_date, :rank_in_set],
              name: "index_chs_on_set_date_rank"
  end
end
