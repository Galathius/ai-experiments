class GoogleController < ApplicationController
  before_action :authenticate

  def index
    @google_identity = Current.user.google_identity
    @emails_count = Current.user.emails.count
    @calendar_events_count = Current.user.calendar_events.count

    # Add sync status information
    @last_email_sync = Current.user.emails.maximum(:updated_at)
    @last_calendar_sync = Current.user.calendar_events.maximum(:updated_at)
    @sync_status = get_sync_status
  end

  def disconnect
    google_identity = Current.user.google_identity
    if google_identity
      # Delete associated data
      Current.user.emails.destroy_all
      Current.user.calendar_events.destroy_all
      google_identity.destroy
      redirect_to google_path, notice: "Google account disconnected successfully."
    else
      redirect_to google_path, alert: "No Google account connected."
    end
  end


  private

  def authenticate
    redirect_to new_session_path unless authenticated?
  end

  def get_sync_status
    return "No Google connection" unless Current.user.google_identity

    sync_threshold = 30.minutes.ago

    email_status = if @last_email_sync.nil?
      "Never synced"
    elsif @last_email_sync > sync_threshold
      "Up to date"
    else
      "Needs sync"
    end

    calendar_status = if @last_calendar_sync.nil?
      "Never synced"
    elsif @last_calendar_sync > sync_threshold
      "Up to date"
    else
      "Needs sync"
    end

    {
      emails: email_status,
      calendar: calendar_status,
      overall: (email_status == "Up to date" && calendar_status == "Up to date") ? "good" : "stale"
    }
  end
end
