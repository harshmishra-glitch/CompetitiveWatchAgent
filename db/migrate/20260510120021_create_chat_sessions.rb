class CreateChatSessions < ActiveRecord::Migration[7.0]
  def change
    create_table :chat_sessions do |t|
      t.belongs_to :pilot_restaurant, null: false, foreign_key: true,
                   index: { name: "index_chat_sessions_on_pilot_restaurant_id" }

      t.string   :title
      t.datetime :started_at, precision: 0, null: false
      t.datetime :last_message_at, precision: 0
      t.integer  :message_count, default: 0, null: false

      t.timestamps
    end

    add_index :chat_sessions,
              [:pilot_restaurant_id, :last_message_at],
              name: "index_chat_sessions_on_pilot_and_last_message"
  end
end
