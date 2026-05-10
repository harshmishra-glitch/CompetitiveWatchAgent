class MenuChangeEvent < ApplicationRecord
  belongs_to :restaurant

  EVENT_TYPES = %w[added removed price_increased price_decreased renamed].freeze

  scope :since, ->(date) { where("scrapped_at_date >= ?", date) }
end
