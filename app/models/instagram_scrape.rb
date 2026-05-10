class InstagramScrape < ApplicationRecord
  belongs_to :restaurant

  has_many :instagram_posts, dependent: :destroy
end
