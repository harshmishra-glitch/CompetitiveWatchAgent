class PilotRestaurant < ApplicationRecord
  belongs_to :restaurant
  has_many :competitor_sets, dependent: :destroy
  has_many :daily_digests, dependent: :destroy
  has_many :chat_sessions, dependent: :destroy
  has_many :threat_assessments, dependent: :destroy

  scope :active, -> { where(active: true) }

  def active_competitor_set
    competitor_sets.where(active: true).order(created_at: :desc).first
  end
end
