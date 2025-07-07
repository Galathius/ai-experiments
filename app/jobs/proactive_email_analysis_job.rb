class ProactiveEmailAnalysisJob < ApplicationJob
  queue_as :default

  def perform(user_id, email_id)
    user = User.find(user_id)
    email = user.emails.find(email_id)
    
    Rails.logger.info "🔍 Running proactive analysis for new email: #{email.subject}"
    
    proactive_service = ProactiveService.new(user)
    proactive_service.check_trigger_based_tasks("email", [email])
    
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "ProactiveEmailAnalysisJob: Record not found - #{e.message}"
  rescue => e
    Rails.logger.error "ProactiveEmailAnalysisJob failed for user #{user_id}, email #{email_id}: #{e.message}"
  end
end