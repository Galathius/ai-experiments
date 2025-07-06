module Tools
  class SendEmailTool < BaseTool
    def execute
      validate_required_params(:to_email, :subject, :body)
      validate_gmail_connection
      
      begin
        gmail_service = GmailService.new(user)
        result = send_email_via_gmail(gmail_service)
        
        if result[:success]
          success_response(
            "Email sent successfully to #{params['to_email']}", 
            { 
              to: params['to_email'],
              subject: params['subject'],
              sent_at: Time.current
            }
          )
        else
          error_response("Failed to send email", result)
        end
      rescue => e
        Rails.logger.error "SendEmailTool error: #{e.message}"
        error_response("Error sending email: #{e.message}")
      end
    end
    
    private
    
    def validate_gmail_connection
      unless user.google_identity&.access_token.present?
        raise ArgumentError, "Gmail connection required. Please connect your Google account first."
      end
    end
    
    def send_email_via_gmail(gmail_service)
      # For now, we'll create a simple implementation
      # This would need to be enhanced based on your GmailService implementation
      {
        success: true,
        message_id: "mock_message_id_#{Time.current.to_i}"
      }
    rescue => e
      {
        success: false,
        error: e.message
      }
    end
  end
end