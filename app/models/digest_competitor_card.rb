class DigestCompetitorCard < ApplicationRecord
  belongs_to :daily_digest
  belongs_to :competitor_restaurant, class_name: "Restaurant"

  RECOMMENDATIONS = %w[defend watch ignore].freeze
  validates :recommendation, inclusion: { in: RECOMMENDATIONS }
end
