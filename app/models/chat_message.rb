class ChatMessage < ApplicationRecord
  belongs_to :chat_session

  ROLES = %w[user assistant tool system].freeze
  validates :role, inclusion: { in: ROLES }
end
