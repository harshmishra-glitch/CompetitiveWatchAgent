class GoogleSerpScrape < ApplicationRecord
  belongs_to :restaurant

  has_many :serp_organic_results, dependent: :destroy
  has_many :serp_questions, dependent: :destroy
end
