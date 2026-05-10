class SerpQuestion < ApplicationRecord
  belongs_to :google_serp_scrape
  belongs_to :restaurant
end
