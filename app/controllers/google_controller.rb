class GoogleController < ApplicationController
  before_action :authenticate

  def index
    @google_identity = Current.user.google_identity
    @emails_count = Current.user.emails.count
    @calendar_events_count = Current.user.calendar_events.count
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

  def import_emails
    google_identity = Current.user.google_identity

    unless google_identity
      redirect_to google_path, alert: "Please connect your Google account first."
      return
    end

    ImportEmailsJob.perform_later(Current.user.id)
    redirect_to google_path, notice: "Email import started. This may take a few minutes."
  end

  def import_calendar
    google_identity = Current.user.google_identity

    unless google_identity
      redirect_to google_path, alert: "Please connect your Google account first."
      return
    end

    ImportCalendarEventsJob.perform_later(Current.user.id)
    redirect_to google_path, notice: "Calendar import started. This may take a few minutes."
  end

  private

  def authenticate
    redirect_to new_session_path unless authenticated?
  end
end
