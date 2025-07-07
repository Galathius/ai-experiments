class DashboardUpdateJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)

    # Use Turbo Streams to update the dashboard sections
    Turbo::StreamsChannel.broadcast_update_to(
      "dashboard_#{user.id}",
      target: "dashboard-content",
      partial: "dashboard/dashboard_content",
      locals: {
        user: user,
        stats: {
          emails: user.emails.count,
          calendar_events: user.calendar_events.count,
          hubspot_contacts: user.hubspot_contacts.count,
          hubspot_notes: user.hubspot_notes.count,
          tasks: user.tasks.count,
          pending_tasks: user.tasks.pending.count
        },
        recent_emails: user.emails.order(received_at: :desc).limit(5),
        closest_events: user.calendar_events.closest.limit(5),
        recent_contacts: user.hubspot_contacts.order(created_at: :desc).limit(5),
        recent_notes: user.hubspot_notes.order(created_at: :desc).limit(5),
        pending_tasks: user.tasks.pending.order(created_at: :desc).limit(10),
        recent_action_logs: user.action_logs.order(created_at: :desc).limit(10)
      }
    )
  end
end
