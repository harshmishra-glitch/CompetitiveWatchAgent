class ThreatAssessment < ApplicationRecord
  belongs_to :pilot_restaurant
  belongs_to :competitor_restaurant, class_name: "Restaurant"
end
