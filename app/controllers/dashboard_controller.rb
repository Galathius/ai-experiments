class DashboardController < ApplicationController
  def index
    @user = Current.user
    @google_connected = @user.google_identity.present?
    @hubspot_connected = @user.hubspot_identity.present?
    
    # Get detailed data for display
    @stats = {
      emails: @user.emails.count,
      calendar_events: @user.calendar_events.count,
      hubspot_contacts: @user.hubspot_contacts.count,
      hubspot_notes: @user.hubspot_notes.count,
      tasks: @user.tasks.count,
      pending_tasks: @user.tasks.pending.count
    }
    
    # Get actual data for inline display
    @recent_emails = @user.emails.order(received_at: :desc).limit(5)
    @upcoming_events = @user.calendar_events.upcoming.order(start_time: :asc).limit(5)
    @recent_contacts = @user.hubspot_contacts.order(created_at: :desc).limit(5)
    @pending_tasks = @user.tasks.pending.order(created_at: :desc).limit(10)
    @recent_action_logs = @user.action_logs.order(created_at: :desc).limit(10)
  end
end