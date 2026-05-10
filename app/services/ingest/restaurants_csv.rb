require "csv"

module Ingest
  class RestaurantsCsv
    DEFAULT_PATH = Rails.root.join("restaurants.csv").to_s

    attr_reader :path

    def initialize(path: DEFAULT_PATH)
      @path = path
    end

    def call
      stats = { read: 0, created: 0, updated: 0, skipped: 0 }

      CSV.foreach(path, headers: true) do |row|
        stats[:read] += 1

        name = Parsers.presence(row["place_name"])
        if name.nil?
          stats[:skipped] += 1
          next
        end

        attrs = {
          maps_url:     Parsers.presence(row["maps_url"]),
          rating:       Parsers.presence(row["rating"]),
          review_count: Parsers.presence(row["review_count"])
        }

        record = Restaurant.find_or_initialize_by(name: name)
        was_new = record.new_record?
        record.assign_attributes(attrs)

        if record.changed?
          record.save!
          was_new ? stats[:created] += 1 : stats[:updated] += 1
        else
          stats[:skipped] += 1
        end
      end

      stats
    end
  end
end
