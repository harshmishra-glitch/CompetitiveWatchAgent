class AddFeedbackToDigestCompetitorCards < ActiveRecord::Migration[7.0]
  def change
    change_table :digest_competitor_cards do |t|
      t.string   :feedback_verdict     # 'agreed' | 'disagreed'
      t.text     :feedback_note
      t.datetime :feedback_at, precision: 0
    end

    add_index :digest_competitor_cards, :feedback_verdict,
              name: "index_digest_cards_on_feedback_verdict"
  end
end
