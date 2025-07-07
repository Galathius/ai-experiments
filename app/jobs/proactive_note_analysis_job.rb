class ProactiveNoteAnalysisJob < ApplicationJob
  queue_as :default

  def perform(user_id, note_id)
    user = User.find(user_id)
    note = user.hubspot_notes.find(note_id)
    
    Rails.logger.info "🔍 Running proactive analysis for new note: #{note.content&.truncate(50)}"
    
    proactive_service = ProactiveService.new(user)
    proactive_service.check_trigger_based_tasks("note", [note])
    
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "ProactiveNoteAnalysisJob: Record not found - #{e.message}"
  rescue => e
    Rails.logger.error "ProactiveNoteAnalysisJob failed for user #{user_id}, note #{note_id}: #{e.message}"
  end
end