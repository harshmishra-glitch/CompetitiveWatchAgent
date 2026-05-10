class CreateChatMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :chat_messages do |t|
      t.belongs_to :chat_session, null: false, foreign_key: true,
                   index: { name: "index_chat_messages_on_chat_session_id" }

      t.string :role, null: false           # 'user' | 'assistant' | 'tool' | 'system'
      t.text   :content
      t.jsonb  :tool_calls
      t.jsonb  :tool_results
      t.jsonb  :citations                   # restaurant_ids / event_ids referenced

      t.string  :model_version
      t.integer :prompt_tokens
      t.integer :completion_tokens
      t.integer :latency_ms

      t.timestamps
    end

    add_index :chat_messages,
              [:chat_session_id, :created_at],
              name: "index_chat_messages_on_session_and_created_at"

    add_index :chat_messages, :role,
              name: "index_chat_messages_on_role"
  end
end
