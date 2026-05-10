class FixInstagramPostsUniqueness < ActiveRecord::Migration[7.0]
  def change
    remove_index :instagram_posts, name: "index_ig_posts_on_ig_id_and_date"

    add_index :instagram_posts,
              [:instagram_scrape_id, :ig_post_id],
              unique: true,
              name:   "index_ig_posts_on_scrape_and_ig_post_id"

    add_index :instagram_posts, [:ig_post_id, :scrapped_at_date],
              name: "index_ig_posts_on_ig_id_and_date"
  end
end
