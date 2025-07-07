class Tools::SearchCalendarEventsTool < Tools::BaseTool
  def self.definition
    {
      "name" => "search_calendar_events",
      "description" => "Search for existing calendar events by title, attendee, date range, or other criteria",
      "parameters" => {
        "type" => "object",
        "properties" => {
          "query" => {
            "type" => "string",
            "description" => "Search query for event title, description, or location"
          },
          "attendee_email" => {
            "type" => "string",
            "description" => "Search for events with a specific attendee email"
          },
          "start_date" => {
            "type" => "string", 
            "description" => "Start date for search range (YYYY-MM-DD format)"
          },
          "end_date" => {
            "type" => "string",
            "description" => "End date for search range (YYYY-MM-DD format)"
          },
          "include_past_events" => {
            "type" => "boolean",
            "description" => "Whether to include past events (default: false)",
            "default" => false
          },
          "limit" => {
            "type" => "integer",
            "description" => "Maximum number of events to return (default: 10)",
            "default" => 10
          }
        },
        "required" => []
      }
    }
  end

  def execute(params)
    query = params["query"]
    attendee_email = params["attendee_email"] 
    start_date = params["start_date"]
    end_date = params["end_date"]
    include_past_events = params["include_past_events"] || false
    limit = params["limit"] || 10

    # Build the search scope
    events = user.calendar_events

    # Filter by date range
    if start_date || end_date
      start_time = start_date ? Date.parse(start_date).beginning_of_day : Time.current.beginning_of_day
      end_time = end_date ? Date.parse(end_date).end_of_day : 1.year.from_now
      events = events.where(start_time: start_time..end_time)
    elsif !include_past_events
      # Default to future events only if no date range specified
      events = events.where("start_time >= ?", Time.current)
    end

    # Filter by query (title, description, location)
    if query.present?
      search_term = "%#{query.downcase}%"
      events = events.where(
        "LOWER(title) LIKE ? OR LOWER(description) LIKE ? OR LOWER(location) LIKE ?",
        search_term, search_term, search_term
      )
    end

    # Filter by attendee email
    if attendee_email.present?
      events = events.where("LOWER(attendees) LIKE ?", "%#{attendee_email.downcase}%")
    end

    # Order by start time and limit results
    events = events.order(:start_time).limit(limit)

    found_events = events.map do |event|
      {
        "id" => event.id,
        "google_event_id" => event.google_event_id,
        "title" => event.title,
        "description" => event.description,
        "location" => event.location,
        "start_time" => event.start_time.strftime("%Y-%m-%d %H:%M"),
        "end_time" => event.end_time&.strftime("%Y-%m-%d %H:%M"),
        "attendees" => event.attendees&.split(',')&.map(&:strip) || [],
        "status" => event.status,
        "creator_email" => event.creator_email,
        "formatted_display" => format_event_for_display(event)
      }
    end

    {
      "success" => true,
      "message" => "Found #{found_events.length} calendar events",
      "events" => found_events,
      "search_criteria" => {
        "query" => query,
        "attendee_email" => attendee_email,
        "start_date" => start_date,
        "end_date" => end_date,
        "include_past_events" => include_past_events,
        "limit" => limit
      }.compact
    }
  rescue Date::Error => e
    error_result("Invalid date format: #{e.message}")
  rescue => e
    error_result("Error searching calendar events: #{e.message}")
  end

  private

  def format_event_for_display(event)
    start_time = event.start_time
    end_time = event.end_time
    
    if start_time.to_date == Date.current
      day_display = "Today"
    elsif start_time.to_date == Date.current + 1.day
      day_display = "Tomorrow"
    elsif start_time.to_date == Date.current - 1.day
      day_display = "Yesterday"
    else
      day_display = start_time.strftime("%A, %B %d, %Y")
    end

    time_display = if end_time
      "#{start_time.strftime('%l:%M %p')} - #{end_time.strftime('%l:%M %p')}"
    else
      start_time.strftime('%l:%M %p')
    end

    location_display = event.location.present? ? " at #{event.location}" : ""
    
    "#{event.title} on #{day_display} #{time_display}#{location_display}".strip
  end
end