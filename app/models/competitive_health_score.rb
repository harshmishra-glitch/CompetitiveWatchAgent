class CompetitiveHealthScore < ApplicationRecord
  belongs_to :restaurant
  belongs_to :competitor_set, optional: true
end
