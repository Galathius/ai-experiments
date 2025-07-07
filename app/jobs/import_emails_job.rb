class ImportEmailsJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    gmail_service = GmailService.new(user)

    begin
      emails_imported = gmail_service.import_emails
      Rails.logger.info "Imported #{emails_imported} emails for user #{user.id}"
    rescue => e
      Rails.logger.error "Email import failed for user #{user.id}: #{e.message}"
      raise e
    end
  end
end
