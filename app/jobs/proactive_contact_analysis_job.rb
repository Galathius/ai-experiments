class ProactiveContactAnalysisJob < ApplicationJob
  queue_as :default

  def perform(user_id, contact_id)
    user = User.find(user_id)
    contact = user.hubspot_contacts.find(contact_id)
    
    Rails.logger.info "🔍 Running proactive analysis for new contact: #{contact.full_name}"
    
    proactive_service = ProactiveService.new(user)
    proactive_service.check_trigger_based_tasks("contact", [contact])
    
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "ProactiveContactAnalysisJob: Record not found - #{e.message}"
  rescue => e
    Rails.logger.error "ProactiveContactAnalysisJob failed for user #{user_id}, contact #{contact_id}: #{e.message}"
  end
end