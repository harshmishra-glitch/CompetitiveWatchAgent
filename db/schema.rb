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

ActiveRecord::Schema[7.0].define(version: 2026_05_10_120004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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

  create_table "restaurants", force: :cascade do |t|
    t.string "name", null: false
    t.text "maps_url"
    t.decimal "rating", precision: 3, scale: 2
    t.integer "review_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_restaurants_on_name"
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

  add_foreign_key "google_review_scrapes", "restaurants"
  add_foreign_key "menu_items", "restaurants_scrapped"
  add_foreign_key "restaurants_scrapped", "restaurants"
end
