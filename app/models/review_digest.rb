class ReviewDigest < ApplicationRecord
  belongs_to :pilot_restaurant
  belongs_to :competitor_set, optional: true

  def self.fetch_or_generate(pilot_restaurant_id:, date:)
    pilot = PilotRestaurant.find(pilot_restaurant_id)
    set_id = pilot.active_competitor_set&.id

    existing = find_by(
      pilot_restaurant_id: pilot_restaurant_id,
      competitor_set_id: set_id,
      digest_date: date
    )
    return existing if existing

    Digest::ReviewGenerator.call(pilot_restaurant_id: pilot_restaurant_id, date: date)
  end
end
