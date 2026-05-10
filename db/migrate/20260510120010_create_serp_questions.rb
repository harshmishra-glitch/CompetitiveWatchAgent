class CreateSerpQuestions < ActiveRecord::Migration[7.0]
  def change
    create_table :serp_questions do |t|
      t.belongs_to :google_serp_scrape, null: false, foreign_key: true,
                   index: { name: "index_serp_questions_on_serp_scrape_id" }
      t.belongs_to :restaurant, null: false, foreign_key: true,
                   index: { name: "index_serp_questions_on_restaurant_id" }

      t.text   :question, null: false
      t.text   :answer
      t.string :title
      t.text   :url
      t.string :date_raw

      t.date :scrapped_at_date, null: false

      t.timestamps
    end

    add_index :serp_questions, [:restaurant_id, :scrapped_at_date],
              name: "index_serp_questions_on_restaurant_and_date"
  end
end
