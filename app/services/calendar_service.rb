require 'google/apis/calendar_v3'
require 'googleauth'

class CalendarService
  def initialize(user)
    @user = user
    @calendar = Google::Apis::CalendarV3::CalendarService.new
    @calendar.authorization = build_authorization
  end

  def import_events(limit: 50)
    return 0 unless @calendar.authorization

    events_imported = 0
    
    # Get events from primary calendar
    result = @calendar.list_events(
      'primary',
      max_results: limit,
      single_events: true,
      order_by: 'startTime',
      time_min: (Time.current - 30.days).iso8601,
      time_max: (Time.current + 90.days).iso8601
    )

    return 0 unless result.items

    # Get existing google_event_ids to avoid duplicates
    existing_ids = @user.calendar_events.pluck(:google_event_id).to_set

    result.items.each do |event|
      begin
        # Skip if already imported
        next if existing_ids.include?(event.id)
        
        # Skip events without start time
        next unless event.start
        
        # Extract event data
        event_data = extract_event_data(event)
        
        # Create calendar event record
        calendar_event = @user.calendar_events.create!(event_data)
        
        # Generate and store embedding
        EmbeddingService.generate_embedding_for_calendar_event(calendar_event)
        
        events_imported += 1
        puts "Imported event: #{calendar_event.title}"
        
      rescue => e
        puts "Error importing event #{event.id}: #{e.message}"
        Rails.logger.error "Error importing event #{event.id}: #{e.message}"
      end
    end

    events_imported
  end

  private

  def build_authorization
    identity = @user.omni_auth_identities.find_by(provider: 'google_oauth2')
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
      title: event.summary || 'No Title',
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
    
    attendees.map { |attendee| attendee.email }.compact.join(', ')
  end
end