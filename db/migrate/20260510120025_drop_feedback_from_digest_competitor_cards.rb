class DropFeedbackFromDigestCompetitorCards < ActiveRecord::Migration[7.0]
  def change
    remove_index  :digest_competitor_cards, name: "index_digest_cards_on_feedback_verdict"
    remove_column :digest_competitor_cards, :feedback_verdict, :string
    remove_column :digest_competitor_cards, :feedback_note,    :text
    remove_column :digest_competitor_cards, :feedback_at,      :datetime, precision: 0
  end
end
