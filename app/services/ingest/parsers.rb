module Ingest
  module Parsers
    module_function

    BOOL_TRUE  = %w[true yes y 1].freeze
    BOOL_FALSE = %w[false no n 0].freeze

    def slug(value)
      value.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/^_|_$/, "")
    end

    def presence(value)
      return nil if value.nil?
      stripped = value.to_s.strip
      stripped.empty? ? nil : stripped
    end

    def integer(value)
      v = presence(value)
      return nil if v.nil?
      digits = v.gsub(/[^\d-]/, "")
      digits.empty? ? nil : digits.to_i
    end

    def decimal(value)
      v = presence(value)
      return nil if v.nil?
      cleaned = v.gsub(/[^\d.\-]/, "")
      cleaned.empty? ? nil : BigDecimal(cleaned)
    rescue ArgumentError
      nil
    end

    def boolean(value)
      v = presence(value)
      return nil if v.nil?
      down = v.downcase
      return true  if BOOL_TRUE.include?(down)
      return false if BOOL_FALSE.include?(down) || down == "no"
      nil
    end

    def cost_for_two(value)
      v = presence(value)
      return nil if v.nil?
      m = v.match(/(\d[\d,]*)/)
      m && m[1].delete(",").to_i
    end

    def total_ratings(value)
      v = presence(value)
      return nil if v.nil?
      return 0 if v.match?(/too few/i)
      m = v.match(/([\d.]+)\s*([Kk]?)/)
      return nil unless m
      n = m[1].to_f
      m[2].downcase == "k" ? (n * 1000).to_i : n.to_i
    end

    def cuisines(value)
      v = presence(value)
      return [] if v.nil?
      v.split(",").map(&:strip).reject(&:empty?)
    end

    def offers(value)
      v = presence(value)
      return [] if v.nil?
      v.split(/\s*\|\s*/).reject(&:empty?)
    end

    def variants(value)
      v = presence(value)
      return nil if v.nil?
      v.split(/\s*\|\s*/).each_with_object({}) do |pair, h|
        label, price_raw = pair.split(/:\s*/, 2)
        next if label.nil? || price_raw.nil?
        h[label.strip] = { "price_raw" => price_raw.strip, "price" => integer(price_raw) }
      end.presence
    end

    def veg(value)
      v = presence(value)
      return nil if v.nil?
      down = v.downcase
      return true  if down == "veg"
      return false if down == "non-veg" || down == "nonveg" || down == "non veg"
      nil
    end

    def datetime(value)
      v = presence(value)
      return nil if v.nil?
      Time.zone.parse(v)
    rescue ArgumentError
      nil
    end

    def review_attributes(value)
      v = presence(value)
      return nil if v.nil?
      JSON.parse(v)
    rescue JSON::ParserError
      nil
    end

    RELATIVE_DATE_RE = /(?:edited\s+)?(?:(an?|\d+)\s+)?(minute|hour|day|week|month|year)s?\s+ago/i.freeze

    def relative_date(value, reference:)
      v = presence(value)
      return nil if v.nil?
      m = v.match(RELATIVE_DATE_RE)
      return nil unless m
      qty = m[1].nil? || m[1].match?(/\Aan?\z/i) ? 1 : m[1].to_i
      unit = m[2].downcase
      case unit
      when "minute" then reference - (qty * 60)
      when "hour"   then reference - (qty * 3600)
      when "day"    then reference - (qty * 86_400)
      when "week"   then reference - (qty * 7 * 86_400)
      when "month"  then reference - (qty * 30 * 86_400)
      when "year"   then reference - (qty * 365 * 86_400)
      end
    end
  end
end
