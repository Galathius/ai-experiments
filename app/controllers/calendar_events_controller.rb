class CalendarEventsController < ApplicationController
  def index
    @calendar_events = Current.user.calendar_events.includes(:embedding).order(start_time: :desc).limit(50)
  end

  def import
    google_identity = Current.user.google_identity
    
    unless google_identity
      redirect_to calendar_events_path, alert: "Please connect your Google account first."
      return
    end

    ImportCalendarEventsJob.perform_later(Current.user.id)
    redirect_to calendar_events_path, notice: "Calendar import started. This may take a few minutes."
  end

  def show
    @calendar_event = Current.user.calendar_events.find(params[:id])
  end
end