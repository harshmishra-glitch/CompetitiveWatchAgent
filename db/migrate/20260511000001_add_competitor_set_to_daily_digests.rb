class AddCompetitorSetToDailyDigests < ActiveRecord::Migration[7.0]
  def up
    execute "TRUNCATE TABLE daily_digests RESTART IDENTITY CASCADE"

    add_reference :daily_digests, :competitor_set,
                  null: true, foreign_key: true,
                  index: { name: "index_daily_digests_on_competitor_set_id" }

    remove_index :daily_digests, name: "index_daily_digests_on_pilot_and_date"

    add_index :daily_digests,
              [:pilot_restaurant_id, :competitor_set_id, :digest_date],
              unique: true,
              name:   "index_daily_digests_on_pilot_set_and_date"
  end

  def down
    remove_index :daily_digests, name: "index_daily_digests_on_pilot_set_and_date"

    add_index :daily_digests,
              [:pilot_restaurant_id, :digest_date],
              unique: true,
              name:   "index_daily_digests_on_pilot_and_date"

    remove_reference :daily_digests, :competitor_set, foreign_key: true
  end
end
