class InstagramPost < ApplicationRecord
  belongs_to :instagram_scrape
  belongs_to :restaurant

  SOURCES = %w[profile hashtag].freeze
  validates :source, inclusion: { in: SOURCES }
end
