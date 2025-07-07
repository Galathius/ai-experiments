class Tools::UpdateCalendarEventTool < Tools::BaseTool
  def self.definition
    {
      "name" => "update_calendar_event",
      "description" => "Update or cancel an existing calendar event",
      "parameters" => {
        "type" => "object",
        "properties" => {
          "event_id" => {
            "type" => "string",
            "description" => "ID of the calendar event to update (can be our database ID or Google event ID)"
          },
          "action" => {
            "type" => "string",
            "enum" => ["update", "cancel", "reschedule"],
            "description" => "Action to perform on the event"
          },
          "new_title" => {
            "type" => "string",
            "description" => "New title for the event (only for update action)"
          },
          "new_start_time" => {
            "type" => "string",
            "description" => "New start time (YYYY-MM-DD HH:MM format, only for update/reschedule)"
          },
          "new_end_time" => {
            "type" => "string", 
            "description" => "New end time (YYYY-MM-DD HH:MM format, only for update/reschedule)"
          },
          "new_description" => {
            "type" => "string",
            "description" => "New description for the event (only for update action)"
          },
          "new_location" => {
            "type" => "string",
            "description" => "New location for the event (only for update action)"
          },
          "attendee_emails" => {
            "type" => "array",
            "items" => {
              "type" => "string"
            },
            "description" => "List of attendee email addresses to add/update (only for update action)"
          },
          "cancellation_reason" => {
            "type" => "string",
            "description" => "Reason for cancellation (only for cancel action)"
          }
        },
        "required" => ["event_id", "action"]
      }
    }
  end

  def execute(params)
    event_id = params["event_id"]
    action = params["action"]

    # Find the event (try both our ID and Google event ID)
    event = find_event(event_id)
    unless event
      return error_result("Calendar event not found with ID: #{event_id}")
    end

    case action
    when "update"
      update_event(event, params)
    when "reschedule"
      reschedule_event(event, params)
    when "cancel"
      cancel_event(event, params)
    else
      error_result("Invalid action: #{action}. Must be 'update', 'reschedule', or 'cancel'")
    end
  rescue => e
    error_result("Error updating calendar event: #{e.message}")
  end

  private

  def find_event(event_id)
    # Try to find by our database ID first
    event = user.calendar_events.find_by(id: event_id)
    return event if event

    # Try to find by Google event ID
    user.calendar_events.find_by(google_event_id: event_id)
  end

  def update_event(event, params)
    google_service = get_google_calendar_service
    unless google_service
      return error_result("Google Calendar service not available")
    end

    begin
      # Get the current event from Google
      google_event = google_service.get_event('primary', event.google_event_id)
      
      # Update fields if provided
      google_event.summary = params["new_title"] if params["new_title"]
      google_event.description = params["new_description"] if params["new_description"]
      google_event.location = params["new_location"] if params["new_location"]

      if params["new_start_time"] && params["new_end_time"]
        start_time = Time.parse(params["new_start_time"])
        end_time = Time.parse(params["new_end_time"])
        
        google_event.start = Google::Apis::CalendarV3::EventDateTime.new(
          date_time: start_time.rfc3339
        )
        google_event.end = Google::Apis::CalendarV3::EventDateTime.new(
          date_time: end_time.rfc3339
        )
      end

      # Update attendees if provided
      if params["attendee_emails"]
        google_event.attendees = params["attendee_emails"].map do |email|
          Google::Apis::CalendarV3::EventAttendee.new(email: email)
        end
      end

      # Update the event in Google Calendar
      updated_google_event = google_service.update_event('primary', event.google_event_id, google_event)

      # Update our local database record
      update_local_event(event, updated_google_event)

      {
        "success" => true,
        "message" => "Calendar event updated successfully",
        "event" => {
          "id" => event.id,
          "google_event_id" => event.google_event_id,
          "title" => event.title,
          "start_time" => event.start_time.strftime("%Y-%m-%d %H:%M"),
          "end_time" => event.end_time.strftime("%Y-%m-%d %H:%M"),
          "location" => event.location,
          "description" => event.description
        }
      }
    rescue Google::Apis::Error => e
      error_result("Google Calendar API error: #{e.message}")
    end
  end

  def reschedule_event(event, params)
    unless params["new_start_time"] && params["new_end_time"]
      return error_result("Both new_start_time and new_end_time are required for rescheduling")
    end

    # Reschedule is essentially an update with new times
    update_params = params.merge({
      "new_title" => event.title,
      "new_description" => event.description,
      "new_location" => event.location
    })

    update_event(event, update_params)
  end

  def cancel_event(event, params)
    google_service = get_google_calendar_service
    unless google_service
      return error_result("Google Calendar service not available")
    end

    begin
      # Cancel the event in Google Calendar
      google_service.delete_event('primary', event.google_event_id)

      # Update our local record to mark as cancelled
      event.update!(
        status: 'cancelled',
        description: [event.description, "Cancelled: #{params['cancellation_reason']}"].compact.join("\n\n")
      )

      {
        "success" => true,
        "message" => "Calendar event cancelled successfully",
        "event" => {
          "id" => event.id,
          "google_event_id" => event.google_event_id,
          "title" => event.title,
          "status" => "cancelled",
          "cancellation_reason" => params["cancellation_reason"]
        }
      }
    rescue Google::Apis::Error => e
      error_result("Google Calendar API error: #{e.message}")
    end
  end

  def get_google_calendar_service
    google_identity = user.google_identity
    return nil unless google_identity

    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = google_identity.to_oauth2_credentials
    service
  rescue => e
    Rails.logger.error "Failed to create Google Calendar service: #{e.message}"
    nil
  end

  def update_local_event(event, google_event)
    event.update!(
      title: google_event.summary,
      description: google_event.description,
      location: google_event.location,
      start_time: google_event.start.date_time || google_event.start.date,
      end_time: google_event.end.date_time || google_event.end.date,
      attendees: google_event.attendees&.map(&:email)&.join(','),
      status: google_event.status
    )
  end
end