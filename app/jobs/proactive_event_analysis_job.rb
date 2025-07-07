class ProactiveEventAnalysisJob < ApplicationJob
  queue_as :default

  def perform(user_id, event_id)
    user = User.find(user_id)
    event = user.calendar_events.find(event_id)
    
    Rails.logger.info "🔍 Running proactive analysis for new calendar event: #{event.title}"
    
    proactive_service = ProactiveService.new(user)
    proactive_service.check_trigger_based_tasks("calendar_event", [event])
    
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "ProactiveEventAnalysisJob: Record not found - #{e.message}"
  rescue => e
    Rails.logger.error "ProactiveEventAnalysisJob failed for user #{user_id}, event #{event_id}: #{e.message}"
  end
end