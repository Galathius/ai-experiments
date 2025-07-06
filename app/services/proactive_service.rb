class ProactiveService
  def initialize(user)
    @user = user
  end

  def self.run_for_all_users
    User.find_each do |user|
      new(user).check_and_notify
    end
  end

  def check_and_notify
    check_overdue_tasks
    check_due_soon_tasks
    check_upcoming_calendar_events
    generate_proactive_suggestions
  end

  private

  def check_overdue_tasks
    overdue_tasks = @user.tasks.overdue

    overdue_tasks.each do |task|
      # Only notify once per day for overdue tasks
      next if recent_notification_exists?("task_overdue", task.id)

      create_notification(
        title: "⚠️ Overdue Task",
        message: "Task '#{task.title}' was due #{time_ago_in_words(task.due_date)} ago. Consider updating the due date or completing it.",
        notification_type: "task_overdue",
        metadata: {
          task_id: task.id,
          task_title: task.title,
          due_date: task.due_date,
          days_overdue: (Time.current.to_date - task.due_date.to_date).to_i
        }
      )
    end
  end

  def check_due_soon_tasks
    due_soon_tasks = @user.tasks.due_soon.where.not(id: @user.tasks.overdue.pluck(:id))

    due_soon_tasks.each do |task|
      # Only notify once for due soon tasks
      next if notification_exists?("task_reminder", task.id)

      days_until_due = (task.due_date.to_date - Time.current.to_date).to_i
      time_phrase = case days_until_due
                   when 0 then "today"
                   when 1 then "tomorrow"
                   else "in #{days_until_due} days"
                   end

      create_notification(
        title: "📅 Task Due Soon",
        message: "Task '#{task.title}' is due #{time_phrase}. Would you like to work on it now?",
        notification_type: "task_reminder",
        metadata: {
          task_id: task.id,
          task_title: task.title,
          due_date: task.due_date,
          days_until_due: days_until_due
        }
      )
    end
  end

  def check_upcoming_calendar_events
    upcoming_events = @user.calendar_events
                          .where(start_time: 1.hour.from_now..4.hours.from_now)
                          .where.not(id: recent_calendar_notifications)

    upcoming_events.each do |event|
      time_until = ((event.start_time - Time.current) / 1.hour).round
      
      create_notification(
        title: "🗓️ Upcoming Meeting",
        message: "Meeting '#{event.title}' starts in #{time_until} hour(s) at #{event.start_time.strftime('%I:%M %p')}.",
        notification_type: "calendar_reminder",
        metadata: {
          event_id: event.id,
          event_title: event.title,
          start_time: event.start_time,
          location: event.location
        }
      )
    end
  end

  def generate_proactive_suggestions
    # Generate smart suggestions based on user patterns
    suggestions = []

    # Suggest creating tasks from recent emails that mention deadlines or follow-ups
    recent_emails = @user.emails.where(received_at: 3.days.ago..Time.current).limit(10)
    recent_emails.each do |email|
      if email.body.to_s.match?(/(follow.?up|deadline|due|remind|schedule)/i)
        suggestions << {
          type: "email_to_task",
          email_id: email.id,
          suggestion: "Consider creating a task based on: #{email.subject}"
        }
      end
    end

    # Suggest following up on completed tasks
    recently_completed = @user.tasks.completed.where(completed_at: 1.day.ago..Time.current)
    recently_completed.each do |task|
      if task.description.to_s.match?(/(client|meeting|proposal|project)/i)
        suggestions << {
          type: "follow_up",
          task_id: task.id,
          suggestion: "Consider following up on completed task: #{task.title}"
        }
      end
    end

    # Create suggestion notification if we have any
    if suggestions.any? && !recent_notification_exists?("proactive_suggestion")
      suggestion_text = suggestions.first(3).map { |s| "• #{s[:suggestion]}" }.join("\n")
      
      create_notification(
        title: "💡 Smart Suggestions",
        message: "Based on your recent activity, here are some suggestions:\n\n#{suggestion_text}",
        notification_type: "proactive_suggestion",
        metadata: { suggestions: suggestions.first(3) }
      )
    end
  end

  def create_notification(title:, message:, notification_type:, metadata: {})
    @user.notifications.create!(
      title: title,
      message: message,
      notification_type: notification_type,
      metadata: metadata
    )
  end

  def notification_exists?(type, related_id = nil)
    scope = @user.notifications.by_type(type).where(created_at: 24.hours.ago..Time.current)
    
    if related_id
      scope = scope.where("metadata->>'task_id' = ? OR metadata->>'event_id' = ?", 
                         related_id.to_s, related_id.to_s)
    end
    
    scope.exists?
  end

  def recent_notification_exists?(type, related_id = nil)
    scope = @user.notifications.by_type(type).where(created_at: 6.hours.ago..Time.current)
    
    if related_id
      scope = scope.where("metadata->>'task_id' = ? OR metadata->>'event_id' = ?", 
                         related_id.to_s, related_id.to_s)
    end
    
    scope.exists?
  end

  def recent_calendar_notifications
    @user.notifications
         .by_type("calendar_reminder")
         .where(created_at: 2.hours.ago..Time.current)
         .pluck(Arel.sql("(metadata->>'event_id')::integer"))
         .compact
  end

  def time_ago_in_words(time)
    distance = Time.current - time
    case distance
    when 0..1.hour
      "#{(distance / 1.minute).round} minutes"
    when 1.hour..24.hours
      "#{(distance / 1.hour).round} hours"
    when 1.day..7.days
      "#{(distance / 1.day).round} days"
    else
      "#{(distance / 1.week).round} weeks"
    end
  end
end