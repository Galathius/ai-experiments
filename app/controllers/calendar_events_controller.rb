class CalendarEventsController < ApplicationController
  def index
    @calendar_events = Current.user.calendar_events.includes(:embedding).order(start_time: :desc).limit(50)
  end

  def import
    calendar_service = CalendarService.new(Current.user)
    
    begin
      events_imported = calendar_service.import_events(limit: params[:limit]&.to_i || 50)
      
      if events_imported > 0
        redirect_to calendar_events_path, notice: "Successfully imported #{events_imported} calendar events!"
      else
        redirect_to calendar_events_path, alert: "No new calendar events to import."
      end
    rescue => e
      Rails.logger.error "Calendar import failed: #{e.message}"
      redirect_to calendar_events_path, alert: "Failed to import calendar events. Please check your Google Calendar connection."
    end
  end

  def show
    @calendar_event = Current.user.calendar_events.find(params[:id])
  end
end