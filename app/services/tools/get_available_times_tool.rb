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
            required: ["start_date", "end_date"]
          }
        }
      }
    end

    def execute
    start_date = Date.parse(params["start_date"])
    end_date = Date.parse(params["end_date"])
    duration_minutes = params["duration_minutes"] || 60
    working_hours_start = params["working_hours_start"] || "09:00"
    working_hours_end = params["working_hours_end"] || "17:00"
    max_suggestions = params["max_suggestions"] || 5

    # Validate date range
      if start_date > end_date
        return error_response("Start date must be before or equal to end date")
      end

      if start_date < Date.current
        start_date = Date.current
      end

    available_slots = find_available_slots(
      start_date, 
      end_date, 
      duration_minutes, 
      working_hours_start, 
      working_hours_end,
      max_suggestions
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
      error_response("Error finding available times: #{e.message}")
    end

  private

  def find_available_slots(start_date, end_date, duration_minutes, working_start, working_end, max_suggestions)
    available_slots = []
    current_date = start_date

    while current_date <= end_date && available_slots.length < max_suggestions
      # Skip weekends (Saturday = 6, Sunday = 0)
      unless current_date.wday == 0 || current_date.wday == 6
        daily_slots = find_daily_available_slots(
          current_date, 
          duration_minutes, 
          working_start, 
          working_end
        )
        available_slots.concat(daily_slots)
        
        # Break if we have enough suggestions
        break if available_slots.length >= max_suggestions
      end
      
      current_date += 1.day
    end

    available_slots.first(max_suggestions)
  end

  def find_daily_available_slots(date, duration_minutes, working_start, working_end)
    # Parse working hours
    start_hour, start_minute = working_start.split(':').map(&:to_i)
    end_hour, end_minute = working_end.split(':').map(&:to_i)

    day_start = date.beginning_of_day + start_hour.hours + start_minute.minutes
    day_end = date.beginning_of_day + end_hour.hours + end_minute.minutes

    # Get all events for this day
    existing_events = user.calendar_events
      .where(start_time: day_start.beginning_of_day..day_end.end_of_day)
      .order(:start_time)

    available_slots = []
    current_time = day_start

    # Check for gaps between events
    existing_events.each do |event|
      event_start = [event.start_time, day_start].max
      event_end = [event.end_time, day_end].min

      # Check if there's a gap before this event
      if current_time + duration_minutes.minutes <= event_start
        slot_end = current_time + duration_minutes.minutes
        if slot_end <= day_end
          available_slots << {
            start_time: current_time,
            end_time: slot_end
          }
        end
      end

      # Move current time to after this event
      current_time = [event_end, current_time].max
    end

    # Check for time after the last event
    if current_time + duration_minutes.minutes <= day_end
      available_slots << {
        start_time: current_time,
        end_time: current_time + duration_minutes.minutes
      }
    end

    # Filter out slots that are too close to current time (need at least 1 hour notice)
    now = Time.current
    available_slots.select do |slot|
      slot[:start_time] > now + 1.hour
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