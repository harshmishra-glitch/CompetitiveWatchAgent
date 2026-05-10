class ChatSession < ApplicationRecord
  belongs_to :pilot_restaurant
  has_many :chat_messages, dependent: :destroy
end
