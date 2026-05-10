class Restaurant < ApplicationRecord
  has_many :scrapes,
           class_name: "RestaurantsScrapped",
           dependent:  :destroy

  has_many :menu_items, through: :scrapes

  has_many :google_review_scrapes, dependent: :destroy
end
