class ActionLog < ApplicationRecord
  belongs_to :user

  validates :tool_name, presence: true
  validates :parameters, presence: true
  validates :result, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where("result->>'success' = 'true'") }
  scope :failed, -> { where("result->>'success' = 'false'") }

  def successful?
    result&.dig("success") == true
  end

  def error_message
    result&.dig("error")
  end

  def summary
    case tool_name
    when "send_email"
      "📧 Email to #{parameters['to_email']}"
    when "create_calendar_event"
      "📅 Event: #{parameters['title']}"
    when "add_hubspot_note"
      "📝 Note for #{parameters['contact_name']}"
    else
      "🔧 #{tool_name}"
    end
  end
end
