class CompetitorSetMember < ApplicationRecord
  belongs_to :competitor_set
  belongs_to :restaurant

  SOURCES = %w[suggested manual].freeze
  validates :source, inclusion: { in: SOURCES }

  scope :active, -> { where(removed_at: nil) }
end
