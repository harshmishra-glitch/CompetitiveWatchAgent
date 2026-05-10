class CompetitorActivityEvent < ApplicationRecord
  belongs_to :restaurant

  scope :since, ->(date) { where("occurred_on >= ?", date) }
  scope :of_types, ->(types) { types.present? ? where(event_type: types) : all }
end
