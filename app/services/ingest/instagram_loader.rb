require "json"

module Ingest
  class InstagramLoader
    def self.load(scrapes_dir:, restaurants_by_slug:, scrapped_at:, scrapped_at_date:)
      stats = { ig_scrapes: 0, ig_posts: 0, skipped_no_match: 0 }
      return stats unless Dir.exist?(scrapes_dir)

      Dir.glob(File.join(scrapes_dir, "*.json")).sort.each do |path|
        slug       = Parsers.slug(File.basename(path, ".json"))
        restaurant = restaurants_by_slug[slug]

        if restaurant.nil?
          stats[:skipped_no_match] += 1
          warn "[instagram] no Restaurant for slug=#{slug.inspect} (#{File.basename(path)})"
          next
        end

        payload = parse_json(path)
        next if payload.nil?

        profile_posts = Array(payload["profile_posts"])
        hashtag_posts = Array(payload["hashtag_posts"])
        handle = profile_posts.first&.dig("owner_username")

        scrape = InstagramScrape
                   .where(restaurant_id: restaurant.id, scrapped_at_date: scrapped_at_date)
                   .first_or_initialize
        scrape.update!(
          handle:             handle,
          profile_post_count: profile_posts.size,
          hashtag_post_count: hashtag_posts.size,
          payload:            payload,
          scrapped_at:        scrapped_at,
          scrapped_at_date:   scrapped_at_date
        )

        rows = []
        profile_posts.each { |post| rows << build_profile_row(post, scrape, restaurant, scrapped_at_date) }
        hashtag_posts.each { |post| rows << build_hashtag_row(post, scrape, restaurant, scrapped_at_date) }
        rows.compact!
        rows.uniq! { |r| r[:ig_post_id] }

        InstagramPost
          .where(instagram_scrape_id: scrape.id)
          .delete_all

        rows.each_slice(500) do |slice|
          InstagramPost.insert_all!(slice)
        end

        stats[:ig_scrapes] += 1
        stats[:ig_posts]   += rows.size
      end

      stats
    end

    def self.parse_json(path)
      JSON.parse(File.read(path))
    rescue JSON::ParserError => e
      warn "[instagram] cannot parse #{File.basename(path)}: #{e.message}"
      nil
    end

    def self.build_profile_row(post, scrape, restaurant, scrapped_at_date)
      ig_post_id = Parsers.presence(post["post_id"]) || Parsers.presence(post["shortcode"])
      return nil if ig_post_id.nil?

      now = Time.current
      {
        instagram_scrape_id:     scrape.id,
        restaurant_id:           restaurant.id,
        source:                  "profile",
        ig_post_id:              ig_post_id,
        shortcode:               Parsers.presence(post["shortcode"]),
        post_url:                Parsers.presence(post["post_url"]),
        post_type:               Parsers.presence(post["post_type"]),
        is_video:                post["is_video"] == true,
        owner_username:          Parsers.presence(post["owner_username"]),
        owner_id:                Parsers.presence(post["owner_id"]),
        caption:                 Parsers.presence(post["caption"]),
        caption_sentiment:       Parsers.presence(post["caption_sentiment"]),
        caption_sentiment_score: Parsers.decimal(post["caption_sentiment_score"]),
        detected_language:       Parsers.presence(post["detected_language"]),
        content_category:        Parsers.presence(post["content_category"]),
        hashtags:                Array(post["hashtags"]),
        mentions:                Array(post["mentions"]),
        detected_themes:         Array(post["detected_themes"]),
        is_promotional:          post["is_promotional"] == true,
        has_discount_code:       post["has_discount_code"] == true,
        has_call_to_action:      post["has_call_to_action"] == true,
        likes_count:             Parsers.integer(post["likes_count"]),
        comments_count:          Parsers.integer(post["comments_count"]),
        engagement_score:        Parsers.integer(post["engagement_score"]),
        estimated_reach:         Parsers.integer(post["estimated_reach"]),
        estimated_impressions:   Parsers.integer(post["estimated_impressions"]),
        posted_at:               profile_posted_at(post),
        scrapped_at_date:        scrapped_at_date,
        raw:                     post,
        created_at:              now,
        updated_at:              now
      }
    end

    def self.build_hashtag_row(post, scrape, restaurant, scrapped_at_date)
      ig_post_id = Parsers.presence(post["id"]) || Parsers.presence(post["shortCode"])
      return nil if ig_post_id.nil?

      now = Time.current
      {
        instagram_scrape_id:     scrape.id,
        restaurant_id:           restaurant.id,
        source:                  "hashtag",
        ig_post_id:              ig_post_id,
        shortcode:               Parsers.presence(post["shortCode"]),
        post_url:                Parsers.presence(post["url"]),
        post_type:               Parsers.presence(post["type"]),
        is_video:                Parsers.presence(post["type"])&.casecmp?("video") || false,
        owner_username:          Parsers.presence(post["ownerUsername"]),
        owner_id:                Parsers.presence(post["ownerId"]),
        caption:                 Parsers.presence(post["caption"]),
        caption_sentiment:       nil,
        caption_sentiment_score: nil,
        detected_language:       nil,
        content_category:        nil,
        hashtags:                Array(post["hashtags"]),
        mentions:                Array(post["mentions"]),
        detected_themes:         [],
        is_promotional:          false,
        has_discount_code:       false,
        has_call_to_action:      false,
        likes_count:             Parsers.integer(post["likesCount"]),
        comments_count:          Parsers.integer(post["commentsCount"]),
        engagement_score:        nil,
        estimated_reach:         nil,
        estimated_impressions:   nil,
        posted_at:               Parsers.datetime(post["timestamp"]),
        scrapped_at_date:        scrapped_at_date,
        raw:                     post,
        created_at:              now,
        updated_at:              now
      }
    end

    def self.profile_posted_at(post)
      taken_at = post["taken_at"]
      return Time.zone.at(taken_at.to_i) if taken_at.is_a?(Numeric) || taken_at.to_s.match?(/\A\d+\z/)
      Parsers.datetime(post["timestamp"])
    end
  end
end
