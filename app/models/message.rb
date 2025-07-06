class Message < ApplicationRecord
  belongs_to :chat

  validates :content, presence: true
  validates :role, presence: true, inclusion: { in: %w[user assistant] }

  scope :ordered, -> { order(:created_at) }
end
