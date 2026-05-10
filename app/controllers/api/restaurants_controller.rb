module Api
  class RestaurantsController < BaseController
    # GET /api/restaurants/search?q=&limit=
    def search
      q = params[:q].to_s.strip
      limit = [[params[:limit].to_i, 10].max, 50].min

      if q.empty?
        render(json: { results: [] }) and return
      end

      pattern = "%#{q.downcase}%"
      rows = Restaurant
               .where("LOWER(name) LIKE ?", pattern)
               .order(Arel.sql("review_count DESC NULLS LAST"))
               .limit(limit)

      render json: { results: rows.map { |r| search_row(r) } }
    end

    # GET /api/restaurants/:id
    def show
      restaurant = Restaurant.find(params[:id])
      snap = latest_snapshot(restaurant)
      render json: { restaurant: restaurant_payload(restaurant, snap) }
    end

    # GET /api/restaurants/:id/menu?date=
    def menu
      restaurant = Restaurant.find(params[:id])
      snap = scrape_for_date(restaurant, parse_date(params[:date], default: nil))
      return render_error(:not_found, "no_menu_snapshot", "No menu snapshot for the requested date") if snap.nil?

      items = MenuItem.where(restaurants_scrapped_id: snap.id).order(:category, :name)
      render json: {
        scrapped_at_date: snap.scrapped_at_date,
        items: items.map { |i| menu_item_payload(i) }
      }
    end

    # GET /api/restaurants/:id/menu_changes?since=30d
    def menu_changes
      restaurant = Restaurant.find(params[:id])
      since_date = parse_since(params[:since])

      events = MenuChangeEvent
                 .where(restaurant_id: restaurant.id)
                 .since(since_date)
                 .order(scrapped_at_date: :desc, id: :desc)
                 .limit(per_page)

      render json: {
        since: since_date,
        events: events.map { |e| menu_change_payload(e) }
      }
    end

    # GET /api/restaurants/:id/rating_trend?from=&to=
    def rating_trend
      restaurant = Restaurant.find(params[:id])
      from = parse_date(params[:from], default: 30.days.ago.to_date)
      to   = parse_date(params[:to],   default: Date.current)

      series = restaurant.scrapes
                         .where(scrapped_at_date: from..to)
                         .order(:scrapped_at_date)
                         .pluck(:scrapped_at_date, :avg_rating, :total_ratings, :google_rating, :google_rating_count)

      render json: {
        from: from, to: to,
        series: series.map { |d, ar, tr, gr, grc|
          { date: d, avg_rating: ar, total_ratings: tr, google_rating: gr, google_rating_count: grc }
        }
      }
    end

    # GET /api/restaurants/:id/pricing_analysis?compare_to=
    def pricing_analysis
      target = Restaurant.find(params[:id])
      pilot_id = params[:compare_to].presence || current_pilot_restaurant&.restaurant_id
      return render_error(:bad_request, "missing_compare_to", "compare_to or pilot context required") if pilot_id.nil?

      pilot = Restaurant.find(pilot_id)
      categories = category_avg_prices(target).each_with_object({}) do |(cat, target_avg), h|
        h[cat] = { target_avg: target_avg }
      end
      category_avg_prices(pilot).each do |cat, pilot_avg|
        categories[cat] ||= {}
        categories[cat][:pilot_avg] = pilot_avg
      end
      categories.each do |_, v|
        v[:delta] = (v[:target_avg].to_f - v[:pilot_avg].to_f).round(2) if v[:target_avg] && v[:pilot_avg]
      end

      render json: {
        target_id: target.id, pilot_id: pilot.id,
        categories: categories.map { |k, v| v.merge(name: k) }
      }
    end

    # GET /api/restaurants/:id/activity_feed?since=&types=
    def activity_feed
      restaurant = Restaurant.find(params[:id])
      since_date = parse_since(params[:since])
      types = params[:types].to_s.split(",").map(&:strip).reject(&:empty?)

      events = CompetitorActivityEvent
                 .where(restaurant_id: restaurant.id)
                 .since(since_date)
                 .of_types(types)
                 .order(occurred_on: :desc, significance: :desc, id: :desc)
                 .limit(per_page)

      render json: {
        since: since_date,
        events: events.map { |e| activity_event_payload(e) }
      }
    end

    # GET /api/restaurants/:id/social_signals?since=
    def social_signals
      restaurant = Restaurant.find(params[:id])
      since_date = parse_since(params[:since], default_days: 14)

      posts = InstagramPost
                .where(restaurant_id: restaurant.id)
                .where("posted_at >= ?", since_date)
                .order(posted_at: :desc)
                .limit(per_page)

      render json: {
        since: since_date,
        posts: posts.map { |p| social_post_payload(p) }
      }
    end

    # GET /api/restaurants/:id/google_reviews?since=&limit=
    def google_reviews
      restaurant = Restaurant.find(params[:id])
      since_date = parse_since(params[:since], default_days: 30)
      limit      = (params[:limit].presence || 50).to_i.clamp(1, 200)

      scrapes = GoogleReviewScrape
                  .where(restaurant_id: restaurant.id)
                  .where("scrapped_at_date >= ?", since_date)
                  .order(scrapped_at_date: :desc)

      reviews = scrapes.flat_map { |s|
        Array(s.reviews).map { |r| r.merge("scrapped_at_date" => s.scrapped_at_date.to_s) }
      }
      reviews = reviews.first(limit)

      ratings = reviews.map { |r| r["rating"] }.compact
      summary = {
        count: reviews.size,
        avg_rating: ratings.any? ? (ratings.sum.to_f / ratings.size).round(2) : nil,
        rating_breakdown: (1..5).map { |star| [star, ratings.count(star)] }.to_h
      }

      render json: {
        restaurant_id: restaurant.id,
        since:         since_date,
        summary:       summary,
        reviews:       reviews.map { |r|
          {
            review_id:      r["review_id"],
            reviewer_name:  r["reviewer_name"],
            local_guide:    r["local_guide"],
            rating:         r["rating"],
            review_text:    r["review_text"],
            likes:          r["likes"],
            date_raw:       r["date_raw"],
            attributes:     r["attributes"],
            scrapped_at_date: r["scrapped_at_date"]
          }
        }
      }
    end

    # GET /api/restaurants/:id/serp_presence?date=
    def serp_presence
      restaurant = Restaurant.find(params[:id])
      date = parse_date(params[:date], default: nil)

      scrape = if date
                 GoogleSerpScrape.find_by(restaurant_id: restaurant.id, scrapped_at_date: date)
               else
                 GoogleSerpScrape.where(restaurant_id: restaurant.id).order(scrapped_at_date: :desc).first
               end
      return render_error(:not_found, "no_serp_scrape", "No SERP scrape available") if scrape.nil?

      results = SerpOrganicResult
                  .where(google_serp_scrape_id: scrape.id)
                  .order(:position)
      questions = SerpQuestion.where(google_serp_scrape_id: scrape.id)

      render json: {
        scrapped_at_date: scrape.scrapped_at_date,
        search_term:      scrape.search_term,
        results_total:    scrape.results_total,
        organic:   results.map { |r| serp_result_payload(r) },
        questions: questions.map { |q| { question: q.question, answer: q.answer, url: q.url } }
      }
    end

    private

    def search_row(r)
      snap = latest_snapshot(r)
      {
        id:           r.id,
        name:         r.name,
        locality:     snap&.locality,
        area:         snap&.area,
        rating:       r.rating,
        review_count: r.review_count,
        image_url:    snap&.image_url
      }
    end

    def latest_snapshot(restaurant)
      restaurant.scrapes.order(scrapped_at_date: :desc).first
    end

    def scrape_for_date(restaurant, date)
      scope = restaurant.scrapes
      date ? scope.find_by(scrapped_at_date: date) : scope.order(scrapped_at_date: :desc).first
    end

    def restaurant_payload(r, snap)
      {
        id:               r.id,
        name:             r.name,
        maps_url:         r.maps_url,
        rating:           r.rating,
        review_count:     r.review_count,
        primary_cuisines: r.primary_cuisines,
        price_band:       r.price_band,
        cost_for_two:     r.cost_for_two || snap&.cost_for_two,
        lat:              r.lat || snap&.swiggy_lat,
        lng:              r.lng || snap&.swiggy_lng,
        latest_snapshot: snap && {
          city:        snap.city,
          locality:    snap.locality,
          area:        snap.area,
          address:     snap.address,
          cuisines:    snap.cuisines,
          avg_rating:  snap.avg_rating,
          total_ratings: snap.total_ratings,
          is_open:     snap.is_open,
          image_url:   snap.image_url,
          swiggy_url:  snap.swiggy_url,
          scrapped_at_date: snap.scrapped_at_date
        }
      }
    end

    def menu_item_payload(i)
      {
        id: i.id, category: i.category, subcategory: i.subcategory,
        name: i.name, price: i.price, price_raw: i.price_raw,
        description: i.description, veg: i.veg, rating: i.rating,
        rating_count: i.rating_count, bestseller: i.bestseller,
        availability: i.availability
      }
    end

    def menu_change_payload(e)
      {
        id: e.id, event_type: e.event_type,
        menu_item_name: e.menu_item_name, category: e.category,
        prev_price: e.prev_price, new_price: e.new_price, price_delta: e.price_delta,
        prev_scrapped_at_date: e.prev_scrapped_at_date,
        scrapped_at_date: e.scrapped_at_date
      }
    end

    def activity_event_payload(e)
      {
        id: e.id, event_type: e.event_type, summary: e.summary,
        occurred_on: e.occurred_on, significance: e.significance,
        before: e.before, after: e.after
      }
    end

    def social_post_payload(p)
      {
        id: p.id, source: p.source, ig_post_id: p.ig_post_id,
        post_url: p.post_url, post_type: p.post_type,
        owner_username: p.owner_username, caption: p.caption,
        hashtags: p.hashtags, mentions: p.mentions,
        likes_count: p.likes_count, comments_count: p.comments_count,
        engagement_score: p.engagement_score, posted_at: p.posted_at,
        is_promotional: p.is_promotional, sentiment: p.caption_sentiment
      }
    end

    def serp_result_payload(r)
      {
        position: r.position, title: r.title, url: r.url,
        displayed_url: r.displayed_url, description: r.description,
        result_type: r.result_type, average_rating: r.average_rating,
        number_of_reviews: r.number_of_reviews,
        followers_amount: r.followers_amount, channel_name: r.channel_name
      }
    end

    def category_avg_prices(restaurant)
      snap = latest_snapshot(restaurant)
      return {} if snap.nil?
      MenuItem
        .where(restaurants_scrapped_id: snap.id)
        .where.not(price: nil)
        .group(:category)
        .average(:price)
        .transform_values { |v| v.to_f.round(2) }
    end
  end
end
