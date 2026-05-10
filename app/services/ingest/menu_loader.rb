require "csv"

module Ingest
  class MenuLoader
    def self.load(scrape:, menu_csv_path:)
      return [] unless File.exist?(menu_csv_path)

      rows = []
      CSV.foreach(menu_csv_path, headers: true) do |csv|
        rows << build_attrs(csv)
      end
      return [] if rows.empty?

      MenuItem.where(restaurants_scrapped_id: scrape.id).delete_all
      rows.each_slice(500) do |slice|
        MenuItem.insert_all!(slice.map { |a| a.merge(restaurants_scrapped_id: scrape.id) })
      end
      rows
    end

    def self.build_attrs(row)
      now = Time.current
      {
        category:     Parsers.presence(row["category"]),
        subcategory:  Parsers.presence(row["subcategory"]),
        name:         Parsers.presence(row["name"]) || "(unnamed)",
        price_raw:    Parsers.presence(row["price"]),
        price:        Parsers.integer(row["price"]),
        variants:     Parsers.variants(row["variants"]),
        description:  Parsers.presence(row["description"]),
        veg:          Parsers.veg(row["veg"]),
        rating:       Parsers.decimal(row["rating"]),
        rating_count: Parsers.integer(row["rating_count"]),
        bestseller:   Parsers.boolean(row["bestseller"]) || false,
        availability: Parsers.presence(row["availability"]),
        created_at:   now,
        updated_at:   now
      }
    end
  end
end
