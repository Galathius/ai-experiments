class DashboardBroadcaster
  def self.broadcast_update(user)
    # Fetch fresh data
    stats = {
      emails: user.emails.count,
      calendar_events: user.calendar_events.count,
      hubspot_contacts: user.hubspot_contacts.count,
      hubspot_notes: user.hubspot_notes.count,
      tasks: user.tasks.count,
      pending_tasks: user.tasks.pending.count
    }
    
    recent_emails = user.emails.order(received_at: :desc).limit(5)
    closest_events = user.calendar_events.closest.limit(5)
    recent_contacts = user.hubspot_contacts.order(created_at: :desc).limit(5)
    recent_notes = user.hubspot_notes.order(created_at: :desc).limit(5)
    pending_tasks = user.tasks.pending.order(created_at: :desc).limit(10)
    recent_action_logs = user.action_logs.order(created_at: :desc).limit(10)
    
    # Broadcast the update
    Turbo::StreamsChannel.broadcast_update_to(
      "dashboard_#{user.id}",
      target: "dashboard-content",
      partial: "dashboard/dashboard_content",
      locals: { 
        user: user,
        google_connected: user.google_identity.present?,
        hubspot_connected: user.hubspot_identity.present?,
        stats: stats,
        recent_emails: recent_emails,
        closest_events: closest_events,
        recent_contacts: recent_contacts,
        recent_notes: recent_notes,
        pending_tasks: pending_tasks,
        recent_action_logs: recent_action_logs
      }
    )
  end
end