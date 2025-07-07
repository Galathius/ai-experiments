class CalendarEvent < ApplicationRecord
  belongs_to :user
  has_one :embedding, as: :embeddable, dependent: :destroy

  validates :google_event_id, presence: true, uniqueness: true
  validates :title, presence: true
  validates :start_time, presence: true

  scope :upcoming, -> { where("start_time > ?", Time.current) }
  scope :past, -> { where("end_time < ?", Time.current) }
  scope :today, -> { where(start_time: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :this_week, -> { where(start_time: Time.current.beginning_of_week..Time.current.end_of_week) }
  scope :closest, -> {
    # Order by absolute distance from current time
    select("*, ABS(EXTRACT(EPOCH FROM (start_time - NOW()))) as time_distance")
      .order("time_distance ASC")
  }

  def content_for_embedding
    parts = []

    # Add event title and description
    parts << "Event: #{title}" if title.present?
    parts << description if description.present?

    # Add timing information
    if start_time.present?
      parts << "Start: #{start_time.strftime('%B %d, %Y at %I:%M %p')}"
    end

    if end_time.present?
      parts << "End: #{end_time.strftime('%B %d, %Y at %I:%M %p')}"
    end

    # Add location
    parts << "Location: #{location}" if location.present?

    # Add attendees
    if attendees_array.any?
      parts << "Attendees: #{attendees_array.join(', ')}"
    end

    # Add creator
    parts << "Organizer: #{creator_email}" if creator_email.present?

    # Add status
    parts << "Status: #{status}" if status.present?

    parts.compact.join(" ")
  end

  def attendees_array
    attendees.present? ? attendees.split(",").map(&:strip) : []
  end

  def duration_in_hours
    return nil unless start_time && end_time
    (end_time - start_time) / 1.hour
  end

  def self.semantic_search(query, limit: 10)
    # This will be used for RAG - find events similar to the query
    embeddings = Embedding.semantic_search(query, limit: limit, types: [ "CalendarEvent" ])
    event_ids = embeddings.pluck(:embeddable_id)
    where(id: event_ids)
  end
end
