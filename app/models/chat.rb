class Chat < ApplicationRecord
  belongs_to :user
  has_many :messages, dependent: :destroy

  validates :title, presence: true

  scope :recent, -> { order(updated_at: :desc) }

  def last_message
    messages.last
  end

  def generate_title_from_first_message
    first_message = messages.first
    if first_message&.content.present?
      # Take first few words as title
      words = first_message.content.split.first(5)
      self.title = words.join(" ")
      self.title += "..." if first_message.content.split.length > 5
    end
  end
end
