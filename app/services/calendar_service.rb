class CalendarService
  def initialize(user)
    @user = user
    @calendar = Google::Apis::CalendarV3::CalendarService.new
    @calendar.authorization = build_authorization
  end

  def import_events(batch_size: 100)
    return 0 unless @calendar.authorization

    calendar = @user.get_or_create_calendar
    return if calendar.syncing?

    begin
      calendar.start_sync!
      total_imported = perform_incremental_sync(calendar, batch_size)
      calendar.complete_sync!
      total_imported
    rescue => e
      calendar.fail_sync!(e.message)
      raise e
    end
  end

  def reset_and_import_all(batch_size: 100)
    return 0 unless @calendar.authorization

    calendar = @user.get_or_create_calendar
    calendar.reset_sync!
    import_events(batch_size: batch_size)
  end

  def create_event(title:, start_time:, end_time:, description: nil, attendees: [], location: nil)
    return { success: false, error: "Calendar authorization not available" } unless @calendar.authorization

    begin
      # Create the event object
      event = Google::Apis::CalendarV3::Event.new(
        summary: title,
        description: description,
        location: location,
        start: Google::Apis::CalendarV3::EventDateTime.new(
          date_time: start_time.iso8601,
          time_zone: Time.zone.name
        ),
        end: Google::Apis::CalendarV3::EventDateTime.new(
          date_time: end_time.iso8601,
          time_zone: Time.zone.name
        )
      )

      # Add attendees if provided
      if attendees.any?
        event.attendees = attendees.map do |email|
          Google::Apis::CalendarV3::EventAttendee.new(email: email)
        end
      end

      # Create the event in primary calendar
      result = @calendar.insert_event("primary", event)

      {
        success: true,
        event_id: result.id,
        html_link: result.html_link,
        start_time: result.start.date_time,
        end_time: result.end.date_time
      }
    rescue => e
      Rails.logger.error "Failed to create calendar event: #{e.message}"
      {
        success: false,
        error: e.message
      }
    end
  end

  def find_available_slots(start_date:, end_date:, duration_minutes: 60, working_hours_start: "09:00", working_hours_end: "17:00", max_suggestions: 5)
    return [] unless @calendar.authorization

    # Validate dates
    if start_date > end_date
      Rails.logger.error "Invalid date range: start_date #{start_date} > end_date #{end_date}"
      return []
    end

    # Query Google Calendar free/busy API
    time_min = start_date.beginning_of_day.iso8601
    time_max = end_date.end_of_day.iso8601
    
    Rails.logger.info "FreeBusy query: #{time_min} to #{time_max} (start_date: #{start_date}, end_date: #{end_date})"

    request = Google::Apis::CalendarV3::FreeBusyRequest.new(
      time_min: time_min,
      time_max: time_max,
      items: [Google::Apis::CalendarV3::FreeBusyRequestItem.new(id: "primary")]
    )

    result = @calendar.query_freebusy(request)
    busy_times = result.calendars["primary"]&.busy || []
    
    Rails.logger.info "Google API returned #{busy_times.size} busy periods: #{busy_times.inspect}"

    # Find available slots
    available_slots = []
    current_date = start_date

    while current_date <= end_date && available_slots.length < max_suggestions
      # Skip weekends (Saturday = 6, Sunday = 0)
      unless current_date.wday == 0 || current_date.wday == 6
        daily_slots = find_daily_available_slots_from_busy_times(
          current_date,
          busy_times,
          duration_minutes,
          working_hours_start,
          working_hours_end
        )
        available_slots.concat(daily_slots)

        # Break if we have enough suggestions
        break if available_slots.length >= max_suggestions
      end

      current_date += 1.day
    end

    final_slots = available_slots.first(max_suggestions)
    Rails.logger.info "Returning #{final_slots.size} available slots: #{final_slots.inspect}"
    final_slots
  end

  private

  def find_daily_available_slots_from_busy_times(date, busy_times, duration_minutes, working_start, working_end)
    # Parse working hours
    start_hour, start_minute = working_start.split(":").map(&:to_i)
    end_hour, end_minute = working_end.split(":").map(&:to_i)

    day_start = date.beginning_of_day + start_hour.hours + start_minute.minutes
    day_end = date.beginning_of_day + end_hour.hours + end_minute.minutes

    # Filter busy times for this day and convert to Time objects
    daily_busy_periods = busy_times.select do |busy_period|
      period_start = Time.parse(busy_period.start)
      period_end = Time.parse(busy_period.end)
      
      # Check if busy period overlaps with this day's working hours
      !(period_end <= day_start || period_start >= day_end)
    end.map do |busy_period|
      {
        start: [Time.parse(busy_period.start), day_start].max,
        end: [Time.parse(busy_period.end), day_end].min
      }
    end.sort_by { |period| period[:start] }

    # Find gaps between busy periods
    available_slots = []
    current_time = day_start

    daily_busy_periods.each do |busy_period|
      # Check if there's a gap before this busy period
      if current_time + duration_minutes.minutes <= busy_period[:start]
        slot_end = current_time + duration_minutes.minutes
        if slot_end <= day_end
          available_slots << {
            start_time: current_time,
            end_time: slot_end
          }
        end
      end

      # Move current time to after this busy period
      current_time = [busy_period[:end], current_time].max
    end

    # Check for time after the last busy period
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

  def perform_incremental_sync(calendar, batch_size)
    total_imported = 0
    page_token = calendar.next_page_token
    sync_token = calendar.last_sync_token
    processed_count = 0

    sync_type = calendar.initial_sync? ? "initial" : "incremental"
    Rails.logger.info "Starting #{sync_type} Calendar sync for user #{@user.id}"

    # For incremental sync, use sync_token if available, otherwise fall back to time range
    if sync_token.present?
      # Incremental sync using sync token
      total_imported = sync_with_token(calendar, sync_token)
    else
      # Full sync or first sync - use pagination
      total_imported = sync_with_pagination(calendar, batch_size)
    end

    Rails.logger.info "Calendar sync completed: #{total_imported} events imported (#{sync_type})"
    total_imported
  end

  def sync_with_token(calendar, sync_token)
    events_imported = 0

    begin
      # Use sync token for incremental updates
      result = @calendar.list_events(
        "primary",
        sync_token: sync_token,
        single_events: true
      )

      if result.items&.any?
        events_imported = import_event_batch(result.items)
      end

      # Update sync token for next incremental sync
      if result.next_sync_token
        calendar.update!(last_sync_token: result.next_sync_token)
      end

    rescue Google::Apis::ClientError => e
      if e.status_code == 410 # Gone - sync token expired
        Rails.logger.info "Sync token expired, falling back to full sync"
        calendar.reset_sync!
        return sync_with_pagination(calendar, 100)
      else
        raise e
      end
    end

    events_imported
  end

  def sync_with_pagination(calendar, batch_size)
    total_imported = 0
    page_token = calendar.next_page_token
    processed_count = 0

    loop do
      # Get events from primary calendar with pagination
      result = @calendar.list_events(
        "primary",
        max_results: batch_size,
        page_token: page_token,
        single_events: true,
        order_by: "startTime",
        time_min: (Time.current - 90.days).iso8601,
        time_max: (Time.current + 180.days).iso8601
      )

      break unless result.items&.any?

      # Process batch of events
      batch_imported = import_event_batch(result.items)
      total_imported += batch_imported
      processed_count += result.items.length

      Rails.logger.info "Calendar sync progress: #{processed_count} processed, #{total_imported} imported"

      # Update calendar with current page token
      page_token = result.next_page_token
      calendar.update!(next_page_token: page_token)

      # Store sync token for future incremental syncs
      if result.next_sync_token
        calendar.update!(last_sync_token: result.next_sync_token)
      end

      # If no more pages, we've reached the end
      break unless page_token

      # Rate limiting
      sleep(0.1)
    end

    total_imported
  end

  def import_event_batch(events)
    events_imported = 0
    existing_ids = @user.calendar_events.pluck(:google_event_id).to_set
    calendar = @user.get_or_create_calendar

    events.each do |event|
      begin
        # Skip if already imported
        next if existing_ids.include?(event.id)

        # Skip events without start time
        next unless event.start

        # Skip cancelled events
        next if event.status == "cancelled"

        # Extract event data
        event_data = extract_event_data(event)

        # Create calendar event record
        calendar_event = @user.calendar_events.create!(event_data)

        # Generate and store embedding
        EmbeddingService.generate_embedding_for_calendar_event(calendar_event)

        # Trigger proactive analysis only for incremental syncs (not initial)
        if !calendar.initial_sync?
          ProactiveEventAnalysisJob.perform_later(@user.id, calendar_event.id)
          Rails.logger.debug "Triggered proactive analysis for new event: #{calendar_event.title}"
        end

        events_imported += 1
        Rails.logger.debug "Imported event: #{calendar_event.title} (#{calendar_event.google_event_id})"

      rescue => e
        Rails.logger.error "Error importing event #{event.id}: #{e.message}"
        next
      end
    end

    events_imported
  end

  def build_authorization
    identity = @user.omni_auth_identities.find_by(provider: "google_oauth2")
    return nil unless identity&.access_token

    auth = Google::Auth::UserRefreshCredentials.new(
      client_id: Rails.application.credentials.dig(:oauth, :google, :client_id),
      client_secret: Rails.application.credentials.dig(:oauth, :google, :client_secret),
      refresh_token: identity.refresh_token,
      access_token: identity.access_token
    )

    # Refresh token if expired
    if identity.expires_at && identity.expires_at < Time.current
      auth.refresh!
      identity.update!(
        access_token: auth.access_token,
        expires_at: Time.current + auth.expires_in.seconds
      )
    end

    auth
  rescue => e
    Rails.logger.error "Failed to build Calendar authorization: #{e.message}"
    nil
  end

  def extract_event_data(event)
    {
      google_event_id: event.id,
      title: event.summary || "No Title",
      description: event.description,
      start_time: parse_datetime(event.start),
      end_time: parse_datetime(event.end),
      location: event.location,
      attendees: extract_attendees(event.attendees),
      creator_email: event.creator&.email,
      status: event.status
    }
  end

  def parse_datetime(datetime_obj)
    return nil unless datetime_obj

    if datetime_obj.date_time
      datetime_obj.date_time
    elsif datetime_obj.date
      # All-day event
      Date.parse(datetime_obj.date).beginning_of_day
    else
      nil
    end
  end

  def extract_attendees(attendees)
    return nil unless attendees&.any?

    attendees.map { |attendee| attendee.email }.compact.join(", ")
  end
end
