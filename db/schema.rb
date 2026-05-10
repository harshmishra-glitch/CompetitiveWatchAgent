# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2026_05_10_120023) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "chat_messages", force: :cascade do |t|
    t.bigint "chat_session_id", null: false
    t.string "role", null: false
    t.text "content"
    t.jsonb "tool_calls"
    t.jsonb "tool_results"
    t.jsonb "citations"
    t.string "model_version"
    t.integer "prompt_tokens"
    t.integer "completion_tokens"
    t.integer "latency_ms"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_session_id", "created_at"], name: "index_chat_messages_on_session_and_created_at"
    t.index ["chat_session_id"], name: "index_chat_messages_on_chat_session_id"
    t.index ["role"], name: "index_chat_messages_on_role"
  end

  create_table "chat_sessions", force: :cascade do |t|
    t.bigint "pilot_restaurant_id", null: false
    t.string "title"
    t.datetime "started_at", precision: 0, null: false
    t.datetime "last_message_at", precision: 0
    t.integer "message_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pilot_restaurant_id", "last_message_at"], name: "index_chat_sessions_on_pilot_and_last_message"
    t.index ["pilot_restaurant_id"], name: "index_chat_sessions_on_pilot_restaurant_id"
  end

  create_table "competitive_health_scores", force: :cascade do |t|
    t.bigint "restaurant_id", null: false
    t.bigint "competitor_set_id"
    t.date "score_date", null: false
    t.decimal "total_score", precision: 6, scale: 2
    t.decimal "rating_trajectory", precision: 6, scale: 2
    t.decimal "review_velocity", precision: 6, scale: 2
    t.decimal "menu_activity", precision: 6, scale: 2
    t.decimal "social_mentions", precision: 6, scale: 2
    t.decimal "estimated_demand", precision: 6, scale: 2
    t.decimal "serp_visibility", precision: 6, scale: 2
    t.integer "rank_in_set"
    t.decimal "score_delta_7d", precision: 6, scale: 2
    t.text "headline_signal"
    t.jsonb "breakdown"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["competitor_set_id", "score_date", "rank_in_set"], name: "index_chs_on_set_date_rank"
    t.index ["competitor_set_id"], name: "index_chs_on_competitor_set_id"
    t.index ["restaurant_id", "score_date"], name: "index_chs_on_restaurant_and_date", unique: true
    t.index ["restaurant_id"], name: "index_chs_on_restaurant_id"
  end

  create_table "competitor_activity_events", force: :cascade do |t|
    t.bigint "restaurant_id", null: false
    t.string "event_type", null: false
    t.text "summary"
    t.string "detected_from"
    t.bigint "source_record_id"
    t.bigint "menu_change_event_id"
    t.jsonb "before"
    t.jsonb "after"
    t.decimal "significance", precision: 5, scale: 2, default: "0.0", null: false
    t.date "occurred_on", null: false
    t.datetime "detected_at", precision: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type"], name: "index_activity_events_on_event_type"
    t.index ["occurred_on", "significance"], name: "index_activity_events_on_date_and_significance"
    t.index ["restaurant_id", "occurred_on"], name: "index_activity_events_on_restaurant_and_date"
    t.index ["restaurant_id"], name: "index_activity_events_on_restaurant_id"
  end

  create_table "competitor_set_members", force: :cascade do |t|
    t.bigint "competitor_set_id", null: false
    t.bigint "restaurant_id", null: false
    t.string "source", default: "suggested", null: false
    t.datetime "added_at", precision: 0, null: false
    t.datetime "removed_at", precision: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["competitor_set_id", "restaurant_id"], name: "index_csm_on_set_and_restaurant", unique: true
    t.index ["competitor_set_id"], name: "index_csm_on_competitor_set_id"
    t.index ["restaurant_id"], name: "index_csm_on_restaurant_id"
  end

  create_table "competitor_sets", force: :cascade do |t|
    t.bigint "pilot_restaurant_id", null: false
    t.string "name"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pilot_restaurant_id"], name: "index_competitor_sets_on_pilot_restaurant_id"
  end

  create_table "daily_digests", force: :cascade do |t|
    t.bigint "pilot_restaurant_id", null: false
    t.date "digest_date", null: false
    t.text "summary", null: false
    t.string "status", default: "draft", null: false
    t.boolean "quiet_day", default: false, null: false
    t.string "model_version"
    t.jsonb "prompt_context"
    t.datetime "generated_at", precision: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pilot_restaurant_id", "digest_date"], name: "index_daily_digests_on_pilot_and_date", unique: true
    t.index ["pilot_restaurant_id"], name: "index_daily_digests_on_pilot_restaurant_id"
  end

  create_table "digest_competitor_cards", force: :cascade do |t|
    t.bigint "daily_digest_id", null: false
    t.bigint "competitor_restaurant_id", null: false
    t.text "change_summary", null: false
    t.text "why_it_matters"
    t.string "recommendation", null: false
    t.text "rationale"
    t.bigint "source_event_ids", default: [], array: true
    t.decimal "priority", precision: 5, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["competitor_restaurant_id"], name: "index_digest_cards_on_competitor_restaurant_id"
    t.index ["daily_digest_id", "competitor_restaurant_id"], name: "index_digest_cards_on_digest_and_competitor", unique: true
    t.index ["daily_digest_id"], name: "index_digest_cards_on_daily_digest_id"
    t.index ["recommendation"], name: "index_digest_cards_on_recommendation"
  end

  create_table "google_review_scrapes", force: :cascade do |t|
    t.bigint "restaurant_id", null: false
    t.jsonb "reviews"
    t.integer "review_count"
    t.datetime "scrapped_at", precision: 0, null: false
    t.date "scrapped_at_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["restaurant_id", "scrapped_at_date"], name: "index_grs_on_restaurant_and_date", unique: true
    t.index ["restaurant_id"], name: "index_google_review_scrapes_on_restaurant_id"
    t.index ["scrapped_at_date"], name: "index_grs_on_scrapped_at_date"
  end

  create_table "google_serp_scrapes", force: :cascade do |t|
    t.bigint "restaurant_id", null: false
    t.string "search_term"
    t.text "search_url"
    t.integer "results_total"
    t.boolean "has_next_page", default: false, null: false
    t.string "provider_code"
    t.jsonb "payload"
    t.datetime "scrapped_at", precision: 0, null: false
    t.date "scrapped_at_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["restaurant_id", "scrapped_at_date"], name: "index_serp_scrapes_on_restaurant_and_date", unique: true
    t.index ["restaurant_id"], name: "index_google_serp_scrapes_on_restaurant_id"
    t.index ["scrapped_at_date"], name: "index_serp_scrapes_on_scrapped_at_date"
  end

  create_table "instagram_posts", force: :cascade do |t|
    t.bigint "instagram_scrape_id", null: false
    t.bigint "restaurant_id", null: false
    t.string "source", null: false
    t.string "ig_post_id", null: false
    t.string "shortcode"
    t.text "post_url"
    t.string "post_type"
    t.boolean "is_video", default: false, null: false
    t.string "owner_username"
    t.string "owner_id"
    t.text "caption"
    t.string "caption_sentiment"
    t.decimal "caption_sentiment_score", precision: 5, scale: 4
    t.string "detected_language"
    t.string "content_category"
    t.text "hashtags", default: [], array: true
    t.text "mentions", default: [], array: true
    t.text "detected_themes", default: [], array: true
    t.boolean "is_promotional", default: false, null: false
    t.boolean "has_discount_code", default: false, null: false
    t.boolean "has_call_to_action", default: false, null: false
    t.integer "likes_count"
    t.integer "comments_count"
    t.integer "engagement_score"
    t.integer "estimated_reach"
    t.integer "estimated_impressions"
    t.datetime "posted_at", precision: 0
    t.date "scrapped_at_date", null: false
    t.jsonb "raw"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ig_post_id", "scrapped_at_date"], name: "index_ig_posts_on_ig_id_and_date"
    t.index ["instagram_scrape_id", "ig_post_id"], name: "index_ig_posts_on_scrape_and_ig_post_id", unique: true
    t.index ["instagram_scrape_id"], name: "index_ig_posts_on_instagram_scrape_id"
    t.index ["restaurant_id", "posted_at"], name: "index_ig_posts_on_restaurant_and_posted_at"
    t.index ["restaurant_id"], name: "index_ig_posts_on_restaurant_id"
    t.index ["source"], name: "index_ig_posts_on_source"
  end

  create_table "instagram_scrapes", force: :cascade do |t|
    t.bigint "restaurant_id", null: false
    t.string "handle"
    t.integer "profile_post_count", default: 0, null: false
    t.integer "hashtag_post_count", default: 0, null: false
    t.jsonb "payload"
    t.datetime "scrapped_at", precision: 0, null: false
    t.date "scrapped_at_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["restaurant_id", "scrapped_at_date"], name: "index_ig_scrapes_on_restaurant_and_date", unique: true
    t.index ["restaurant_id"], name: "index_instagram_scrapes_on_restaurant_id"
    t.index ["scrapped_at_date"], name: "index_ig_scrapes_on_scrapped_at_date"
  end

  create_table "menu_change_events", force: :cascade do |t|
    t.bigint "restaurant_id", null: false
    t.string "menu_item_name", null: false
    t.string "event_type", null: false
    t.string "category"
    t.string "subcategory"
    t.integer "prev_price"
    t.integer "new_price"
    t.integer "price_delta"
    t.string "prev_name"
    t.string "new_name"
    t.date "prev_scrapped_at_date"
    t.date "scrapped_at_date", null: false
    t.jsonb "before"
    t.jsonb "after"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type"], name: "index_menu_change_events_on_event_type"
    t.index ["restaurant_id", "scrapped_at_date"], name: "index_menu_change_events_on_restaurant_and_date"
    t.index ["restaurant_id"], name: "index_menu_change_events_on_restaurant_id"
  end

  create_table "menu_items", force: :cascade do |t|
    t.bigint "restaurants_scrapped_id", null: false
    t.string "category"
    t.string "subcategory"
    t.string "name", null: false
    t.string "price_raw"
    t.integer "price"
    t.jsonb "variants"
    t.text "description"
    t.boolean "veg"
    t.decimal "rating", precision: 3, scale: 2
    t.integer "rating_count"
    t.boolean "bestseller", default: false, null: false
    t.string "availability"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["restaurants_scrapped_id", "name"], name: "index_menu_items_on_scrap_id_and_name"
    t.index ["restaurants_scrapped_id"], name: "index_menu_items_on_restaurants_scrapped_id"
  end

  create_table "pilot_restaurants", force: :cascade do |t|
    t.bigint "restaurant_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "set_at", precision: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["restaurant_id"], name: "index_pilot_restaurants_on_restaurant_id", unique: true
  end

  create_table "restaurants", force: :cascade do |t|
    t.string "name", null: false
    t.text "maps_url"
    t.decimal "rating", precision: 3, scale: 2
    t.integer "review_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "lat", precision: 10, scale: 7
    t.decimal "lng", precision: 10, scale: 7
    t.text "primary_cuisines", default: [], array: true
    t.string "price_band"
    t.integer "cost_for_two"
    t.index ["lat", "lng"], name: "index_restaurants_on_lat_lng"
    t.index ["name"], name: "index_restaurants_on_name"
    t.index ["price_band"], name: "index_restaurants_on_price_band"
    t.index ["primary_cuisines"], name: "index_restaurants_on_primary_cuisines", using: :gin
  end

  create_table "restaurants_scrapped", force: :cascade do |t|
    t.bigint "restaurant_id", null: false
    t.bigint "swiggy_restaurant_id"
    t.string "input_name"
    t.string "name"
    t.string "city"
    t.string "locality"
    t.string "area"
    t.text "address"
    t.string "cost_for_two_raw"
    t.integer "cost_for_two"
    t.text "cuisines", default: [], array: true
    t.decimal "avg_rating", precision: 3, scale: 2
    t.string "total_ratings_raw"
    t.integer "total_ratings"
    t.decimal "google_rating", precision: 3, scale: 2
    t.integer "google_rating_count"
    t.boolean "pure_veg"
    t.boolean "is_open"
    t.datetime "next_close_time", precision: 0
    t.integer "delivery_time_min"
    t.integer "delivery_time_max"
    t.decimal "distance_km", precision: 6, scale: 2
    t.bigint "parent_id"
    t.boolean "is_chain"
    t.string "discount_header"
    t.text "offers", default: [], array: true
    t.text "image_url"
    t.text "swiggy_url"
    t.decimal "swiggy_lat", precision: 10, scale: 7
    t.decimal "swiggy_lng", precision: 10, scale: 7
    t.jsonb "menu"
    t.datetime "scrapped_at", precision: 0, null: false
    t.date "scrapped_at_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["restaurant_id", "scrapped_at_date"], name: "index_rest_scrap_on_restaurant_and_date", unique: true
    t.index ["restaurant_id"], name: "index_restaurants_scrapped_on_restaurant_id"
    t.index ["scrapped_at_date"], name: "index_rest_scrap_on_scrapped_at_date"
    t.index ["swiggy_restaurant_id", "scrapped_at_date"], name: "index_rest_scrap_on_swiggy_id_and_date", unique: true, where: "(swiggy_restaurant_id IS NOT NULL)"
  end

  create_table "serp_organic_results", force: :cascade do |t|
    t.bigint "google_serp_scrape_id", null: false
    t.bigint "restaurant_id", null: false
    t.integer "position"
    t.string "result_type"
    t.string "title"
    t.text "url"
    t.text "displayed_url"
    t.text "description"
    t.string "channel_name"
    t.decimal "average_rating", precision: 3, scale: 2
    t.integer "number_of_reviews"
    t.string "followers_amount"
    t.string "views"
    t.string "last_updated_raw"
    t.text "emphasized_keywords", default: [], array: true
    t.jsonb "site_links"
    t.jsonb "product_info"
    t.jsonb "raw"
    t.date "scrapped_at_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["google_serp_scrape_id"], name: "index_serp_results_on_serp_scrape_id"
    t.index ["restaurant_id", "scrapped_at_date", "position"], name: "index_serp_results_on_restaurant_date_position"
    t.index ["restaurant_id"], name: "index_serp_results_on_restaurant_id"
    t.index ["result_type"], name: "index_serp_results_on_result_type"
  end

  create_table "serp_questions", force: :cascade do |t|
    t.bigint "google_serp_scrape_id", null: false
    t.bigint "restaurant_id", null: false
    t.text "question", null: false
    t.text "answer"
    t.string "title"
    t.text "url"
    t.string "date_raw"
    t.date "scrapped_at_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["google_serp_scrape_id"], name: "index_serp_questions_on_serp_scrape_id"
    t.index ["restaurant_id", "scrapped_at_date"], name: "index_serp_questions_on_restaurant_and_date"
    t.index ["restaurant_id"], name: "index_serp_questions_on_restaurant_id"
  end

  create_table "threat_assessments", force: :cascade do |t|
    t.bigint "pilot_restaurant_id", null: false
    t.bigint "competitor_restaurant_id", null: false
    t.decimal "segment_overlap", precision: 5, scale: 4
    t.decimal "price_band_overlap", precision: 5, scale: 4
    t.decimal "neighbourhood_overlap", precision: 5, scale: 4
    t.decimal "cuisine_overlap", precision: 5, scale: 4
    t.decimal "total_threat", precision: 5, scale: 4
    t.text "rationale"
    t.jsonb "breakdown"
    t.datetime "computed_at", precision: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["competitor_restaurant_id"], name: "index_threat_on_competitor_restaurant_id"
    t.index ["pilot_restaurant_id", "competitor_restaurant_id"], name: "index_threat_on_pilot_and_competitor", unique: true
    t.index ["pilot_restaurant_id"], name: "index_threat_on_pilot_restaurant_id"
  end

  add_foreign_key "chat_messages", "chat_sessions"
  add_foreign_key "chat_sessions", "pilot_restaurants"
  add_foreign_key "competitive_health_scores", "competitor_sets"
  add_foreign_key "competitive_health_scores", "restaurants"
  add_foreign_key "competitor_activity_events", "restaurants"
  add_foreign_key "competitor_set_members", "competitor_sets"
  add_foreign_key "competitor_set_members", "restaurants"
  add_foreign_key "competitor_sets", "pilot_restaurants"
  add_foreign_key "daily_digests", "pilot_restaurants"
  add_foreign_key "digest_competitor_cards", "daily_digests"
  add_foreign_key "digest_competitor_cards", "restaurants", column: "competitor_restaurant_id"
  add_foreign_key "google_review_scrapes", "restaurants"
  add_foreign_key "google_serp_scrapes", "restaurants"
  add_foreign_key "instagram_posts", "instagram_scrapes"
  add_foreign_key "instagram_posts", "restaurants"
  add_foreign_key "instagram_scrapes", "restaurants"
  add_foreign_key "menu_change_events", "restaurants"
  add_foreign_key "menu_items", "restaurants_scrapped"
  add_foreign_key "pilot_restaurants", "restaurants"
  add_foreign_key "restaurants_scrapped", "restaurants"
  add_foreign_key "serp_organic_results", "google_serp_scrapes"
  add_foreign_key "serp_organic_results", "restaurants"
  add_foreign_key "serp_questions", "google_serp_scrapes"
  add_foreign_key "serp_questions", "restaurants"
  add_foreign_key "threat_assessments", "pilot_restaurants"
  add_foreign_key "threat_assessments", "restaurants", column: "competitor_restaurant_id"
end
