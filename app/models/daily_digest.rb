class DailyDigest < ApplicationRecord
  belongs_to :pilot_restaurant
  has_many :digest_competitor_cards, dependent: :destroy
end
