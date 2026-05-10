class AddBootstrapTrackingToPilotRestaurants < ActiveRecord::Migration[7.0]
  def change
    change_table :pilot_restaurants do |t|
      t.datetime :last_bootstrap_at,     precision: 0
      t.string   :last_bootstrap_job_id
    end

    add_index :pilot_restaurants, :last_bootstrap_at,
              name: "index_pilot_restaurants_on_last_bootstrap_at"
  end
end
