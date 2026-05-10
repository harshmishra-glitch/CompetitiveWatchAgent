class MenuItem < ApplicationRecord
  belongs_to :scrape,
             class_name:  "RestaurantsScrapped",
             foreign_key: :restaurants_scrapped_id
end
