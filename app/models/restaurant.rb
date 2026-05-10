class Restaurant < ApplicationRecord
  has_many :scrapes,
           class_name: "RestaurantsScrapped",
           dependent:  :destroy

  has_many :menu_items, through: :scrapes

  has_many :google_review_scrapes,  dependent: :destroy
  has_many :instagram_scrapes,      dependent: :destroy
  has_many :instagram_posts,        dependent: :destroy
  has_many :google_serp_scrapes,    dependent: :destroy
  has_many :serp_organic_results,   dependent: :destroy
  has_many :serp_questions,         dependent: :destroy
end
