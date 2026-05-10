class CreateInstagramPosts < ActiveRecord::Migration[7.0]
  def change
    create_table :instagram_posts do |t|
      t.belongs_to :instagram_scrape, null: false, foreign_key: true,
                   index: { name: "index_ig_posts_on_instagram_scrape_id" }
      t.belongs_to :restaurant, null: false, foreign_key: true,
                   index: { name: "index_ig_posts_on_restaurant_id" }

      t.string  :source, null: false                  # 'profile' | 'hashtag'
      t.string  :ig_post_id, null: false
      t.string  :shortcode
      t.text    :post_url
      t.string  :post_type
      t.boolean :is_video, default: false, null: false

      t.string  :owner_username
      t.string  :owner_id

      t.text    :caption
      t.string  :caption_sentiment
      t.decimal :caption_sentiment_score, precision: 5, scale: 4
      t.string  :detected_language
      t.string  :content_category

      t.text    :hashtags,        array: true, default: []
      t.text    :mentions,        array: true, default: []
      t.text    :detected_themes, array: true, default: []

      t.boolean :is_promotional,     default: false, null: false
      t.boolean :has_discount_code,  default: false, null: false
      t.boolean :has_call_to_action, default: false, null: false

      t.integer :likes_count
      t.integer :comments_count
      t.integer :engagement_score
      t.integer :estimated_reach
      t.integer :estimated_impressions

      t.datetime :posted_at, precision: 0
      t.date     :scrapped_at_date, null: false

      t.jsonb :raw

      t.timestamps
    end

    add_index :instagram_posts,
              [:instagram_scrape_id, :ig_post_id],
              unique: true,
              name:   "index_ig_posts_on_scrape_and_ig_post_id"

    add_index :instagram_posts, [:ig_post_id, :scrapped_at_date],
              name: "index_ig_posts_on_ig_id_and_date"

    add_index :instagram_posts, [:restaurant_id, :posted_at],
              name: "index_ig_posts_on_restaurant_and_posted_at"

    add_index :instagram_posts, :source,
              name: "index_ig_posts_on_source"
  end
end
