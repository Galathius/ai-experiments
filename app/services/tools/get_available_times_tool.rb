module Tools
  class GetAvailableTimesTool < BaseTool
    def self.openai_definition
      {
        type: "function",
        function: {
          name: tool_name,
          description: "Find available time slots in the user's calendar for scheduling meetings",
          parameters: {
            type: "object",
            properties: {
              start_date: {
                type: "string",
                description: "Start date to search for availability (YYYY-MM-DD format)"
              },
              end_date: {
                type: "string",
                description: "End date to search for availability (YYYY-MM-DD format)"
              },
              duration_minutes: {
                type: "integer",
                description: "Duration of the meeting in minutes (default: 60)"
              },
              working_hours_start: {
                type: "string",
                description: "Start of working hours (HH:MM format, default: 09:00)"
              },
              working_hours_end: {
                type: "string",
                description: "End of working hours (HH:MM format, default: 17:00)"
              },
              max_suggestions: {
                type: "integer",
                description: "Maximum number of time slots to return (default: 5)"
              }
            },
            required: [ "start_date", "end_date" ]
          }
        }
      }
    end

    def execute
      validate_required_params(:start_date, :end_date)
      validate_google_connection

      begin
        Rails.logger.info "GetAvailableTimesTool params: #{params.inspect}"
        
        start_date = Date.parse(params["start_date"])
        end_date = Date.parse(params["end_date"])
        duration_minutes = params["duration_minutes"] || 60
        working_hours_start = params["working_hours_start"] || "09:00"
        working_hours_end = params["working_hours_end"] || "17:00"
        max_suggestions = params["max_suggestions"] || 5

        Rails.logger.info "Parsed dates: start_date=#{start_date}, end_date=#{end_date}, duration=#{duration_minutes}"

        # Validate date range
        if start_date > end_date
          return error_response("Start date must be before or equal to end date")
        end

        if start_date < Date.current
          return error_response("Cannot search for availability in the past. Please specify a date from today (#{Date.current}) onwards.")
        end

        # Use CalendarService to find available slots
        calendar_service = CalendarService.new(user)
        available_slots = calendar_service.find_available_slots(
          start_date: start_date,
          end_date: end_date,
          duration_minutes: duration_minutes,
          working_hours_start: working_hours_start,
          working_hours_end: working_hours_end,
          max_suggestions: max_suggestions
        )

        if available_slots.empty?
          return success_response(
            "No available time slots found in the specified date range",
            {
              available_slots: [],
              search_criteria: {
                start_date: start_date.to_s,
                end_date: end_date.to_s,
                duration_minutes: duration_minutes,
                working_hours: "#{working_hours_start} - #{working_hours_end}"
              }
            }
          )
        end

        success_response(
          "Found #{available_slots.length} available time slots",
          {
            available_slots: available_slots.map do |slot|
              {
                start_time: slot[:start_time].strftime("%Y-%m-%d %H:%M"),
                end_time: slot[:end_time].strftime("%Y-%m-%d %H:%M"),
                formatted_display: format_slot_for_display(slot),
                day_of_week: slot[:start_time].strftime("%A")
              }
            end,
            search_criteria: {
              start_date: start_date.to_s,
              end_date: end_date.to_s,
              duration_minutes: duration_minutes,
              working_hours: "#{working_hours_start} - #{working_hours_end}"
            }
          }
        )

      rescue Date::Error => e
        error_response("Invalid date format: #{e.message}")
      rescue => e
        Rails.logger.error "GetAvailableTimesTool error: #{e.message}"
        error_response("Error finding available times: #{e.message}")
      end
    end

    private

    def validate_google_connection
      unless user.google_identity&.access_token.present?
        raise ArgumentError, "Google Calendar connection required. Please connect your Google account first."
      end
    end

    def format_slot_for_display(slot)
      start_time = slot[:start_time]
      end_time = slot[:end_time]

      if start_time.to_date == Date.current
        day_display = "Today"
      elsif start_time.to_date == Date.current + 1.day
        day_display = "Tomorrow"
      else
        day_display = start_time.strftime("%A, %B %d")
      end

      time_display = "#{start_time.strftime('%l:%M %p')} - #{end_time.strftime('%l:%M %p')}"

      "#{day_display} #{time_display}".strip
    end
  end
end