class CheckTriggeredTasksJob < ApplicationJob
  queue_as :default
  
  def perform(user_id, before_counts)
    user = User.find(user_id)
    proactive_service = ProactiveService.new(user)
    
    Rails.logger.info "Checking for triggered tasks for user #{user_id}"
    
    # Check what's new since the sync started
    after_counts = {
      emails: user.emails.count,
      calendar_events: user.calendar_events.count,
      hubspot_contacts: user.hubspot_contacts.count,
      hubspot_notes: user.hubspot_notes.count
    }
    
    # Find new records and trigger relevant tasks
    check_new_records(user, proactive_service, :emails, before_counts[:emails], after_counts[:emails])
    check_new_records(user, proactive_service, :calendar_events, before_counts[:calendar_events], after_counts[:calendar_events])
    check_new_records(user, proactive_service, :hubspot_contacts, before_counts[:hubspot_contacts], after_counts[:hubspot_contacts])
    check_new_records(user, proactive_service, :hubspot_notes, before_counts[:hubspot_notes], after_counts[:hubspot_notes])
    
  rescue => e
    Rails.logger.error "Failed to check triggered tasks for user #{user_id}: #{e.message}"
  end
  
  private
  
  def check_new_records(user, proactive_service, record_type, before_count, after_count)
    return if after_count <= before_count
    
    new_count = after_count - before_count
    Rails.logger.info "Found #{new_count} new #{record_type} for user #{user.id}"
    
    # Get the newest records (approximate since we don't have exact timestamps)
    case record_type
    when :emails
      new_records = user.emails.order(created_at: :desc).limit(new_count)
      proactive_service.check_trigger_based_tasks('email', new_records)
    when :calendar_events
      new_records = user.calendar_events.order(created_at: :desc).limit(new_count)
      proactive_service.check_trigger_based_tasks('calendar_event', new_records)
    when :hubspot_contacts
      new_records = user.hubspot_contacts.order(created_at: :desc).limit(new_count)
      proactive_service.check_trigger_based_tasks('contact', new_records)
    when :hubspot_notes
      new_records = user.hubspot_notes.order(created_at: :desc).limit(new_count)
      proactive_service.check_trigger_based_tasks('note', new_records)
    end
  end
end