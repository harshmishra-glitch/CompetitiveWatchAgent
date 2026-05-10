class RestaurantsScrapped < ApplicationRecord
  self.table_name = "restaurants_scrapped"

  belongs_to :restaurant

  has_many :menu_items,
           class_name:  "MenuItem",
           foreign_key: :restaurants_scrapped_id,
           dependent:   :destroy
end
