class EmailsController < ApplicationController
  def index
    @emails = Current.user.emails.recent.limit(50)
  end

  def import
    gmail_service = GmailService.new(Current.user)
    
    begin
      emails_imported = gmail_service.import_emails(limit: params[:limit]&.to_i || 50)
      
      if emails_imported > 0
        redirect_to emails_path, notice: "Successfully imported #{emails_imported} emails!"
      else
        redirect_to emails_path, alert: "No new emails to import."
      end
    rescue => e
      Rails.logger.error "Email import failed: #{e.message}"
      redirect_to emails_path, alert: "Failed to import emails. Please check your Gmail connection."
    end
  end

  def show
    @email = Current.user.emails.find(params[:id])
  end
end
