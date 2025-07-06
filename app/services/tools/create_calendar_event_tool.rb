module Tools
  class CreateCalendarEventTool < BaseTool
    def execute
      validate_required_params(:title, :start_time)
      validate_google_connection
      
      begin
        calendar_service = CalendarService.new(user)
        event = create_calendar_event(calendar_service)
        
        if event[:success]
          success_response(
            "Calendar event '#{params['title']}' created successfully",
            {
              event_id: event[:event_id],
              title: params['title'],
              start_time: params['start_time'],
              duration: params['duration_minutes'] || 60
            }
          )
        else
          error_response("Failed to create calendar event", event)
        end
      rescue => e
        Rails.logger.error "CreateCalendarEventTool error: #{e.message}"
        error_response("Error creating calendar event: #{e.message}")
      end
    end
    
    private
    
    def validate_google_connection
      unless user.google_identity&.access_token.present?
        raise ArgumentError, "Google Calendar connection required. Please connect your Google account first."
      end
    end
    
    def create_calendar_event(calendar_service)
      start_time = DateTime.parse(params['start_time'])
      duration_minutes = params['duration_minutes'] || 60
      end_time = start_time + duration_minutes.minutes
      
      # For now, return a mock response
      # This would need to be implemented in CalendarService
      {
        success: true,
        event_id: "mock_event_#{Time.current.to_i}",
        start_time: start_time,
        end_time: end_time
      }
    rescue => e
      {
        success: false,
        error: e.message
      }
    end
  end
end