class CompetitorSet < ApplicationRecord
  belongs_to :pilot_restaurant
  has_many :competitor_set_members, dependent: :destroy
  has_many :restaurants, through: :competitor_set_members
  has_many :competitive_health_scores, dependent: :nullify

  def active_members
    competitor_set_members.where(removed_at: nil)
  end
end
