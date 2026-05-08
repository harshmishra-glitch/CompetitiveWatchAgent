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

ActiveRecord::Schema[7.0].define(version: 2026_05_08_120002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "menu_items", force: :cascade do |t|
    t.bigint "restaurant_id", null: false
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
    t.datetime "scrapped_at", precision: 0, null: false
    t.date "scrapped_at_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["restaurant_id", "name", "scrapped_at_date"], name: "index_menu_items_on_restaurant_name_and_scrape_date"
    t.index ["restaurant_id", "scrapped_at_date"], name: "index_menu_items_on_restaurant_id_and_scrapped_at_date"
    t.index ["restaurant_id"], name: "index_menu_items_on_restaurant_id"
  end

  create_table "restaurant_google_reviews", force: :cascade do |t|
    t.bigint "restaurant_id", null: false
    t.string "restaurant_name"
    t.string "phone"
    t.text "address"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.string "place_type"
    t.text "website"
    t.string "review_id", null: false
    t.string "place_name"
    t.string "reviewer_name"
    t.string "reviewer_id"
    t.boolean "local_guide"
    t.integer "rating"
    t.text "review_text"
    t.integer "likes"
    t.string "date_raw"
    t.datetime "review_posted_at", precision: 0
    t.jsonb "review_attributes"
    t.datetime "scrapped_at", precision: 0, null: false
    t.date "scrapped_at_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["restaurant_id", "review_posted_at"], name: "index_reviews_on_restaurant_and_posted_at"
    t.index ["restaurant_id", "scrapped_at_date"], name: "index_reviews_on_restaurant_and_scrape_date"
    t.index ["restaurant_id"], name: "index_restaurant_google_reviews_on_restaurant_id"
    t.index ["review_id", "scrapped_at_date"], name: "index_reviews_on_review_id_and_scrape_date", unique: true
  end

  create_table "restaurants", force: :cascade do |t|
    t.bigint "swiggy_restaurant_id", null: false
    t.string "input_name"
    t.string "name", null: false
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
    t.jsonb "google_reviews"
    t.datetime "scrapped_at", precision: 0, null: false
    t.date "scrapped_at_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["avg_rating"], name: "index_restaurants_on_avg_rating"
    t.index ["city", "locality"], name: "index_restaurants_on_city_and_locality"
    t.index ["scrapped_at_date"], name: "index_restaurants_on_scrapped_at_date"
    t.index ["swiggy_restaurant_id", "scrapped_at_date"], name: "index_restaurants_on_swiggy_id_and_scrape_date", unique: true
  end

  add_foreign_key "menu_items", "restaurants"
  add_foreign_key "restaurant_google_reviews", "restaurants"
end
