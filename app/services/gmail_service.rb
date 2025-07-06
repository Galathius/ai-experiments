require "google/apis/gmail_v1"
require "googleauth"
require "mail"

class GmailService
  def initialize(user)
    @user = user
    @gmail = Google::Apis::GmailV1::GmailService.new
    @gmail.authorization = build_authorization
  end

  def import_emails(limit: 50)
    return unless @gmail.authorization

    # Get list of message IDs
    message_list = @gmail.list_user_messages(
      "me",
      max_results: limit,
      q: "-in:spam -in:trash" # Exclude spam and trash
    )

    return [] unless message_list.messages

    emails_imported = 0
    message_list.messages.each do |message|
      begin
        # Skip if already imported
        next if Email.exists?(gmail_id: message.id)

        # Get full message details with body content
        full_message = @gmail.get_user_message("me", message.id, format: "full")

        # Extract email data
        email_data = extract_email_data(full_message)

        # Create email record
        email = @user.emails.create!(email_data)

        # Generate and store embedding
        EmbeddingService.generate_embedding_for_email(email)

        emails_imported += 1
        puts "Imported email: #{email.subject}"

      rescue => e
        puts "Error importing email #{message.id}: #{e.message}"
      end
    end

    emails_imported
  end

  def send_email(to_email:, subject:, body:)
    return { success: false, error: "Gmail authorization not available" } unless @gmail.authorization

    begin
      # Create the email message
      message = create_email_message(to_email: to_email, subject: subject, body: body)

      # Send the email
      result = @gmail.send_user_message("me", message)
      
      {
        success: true,
        message_id: result.id,
        thread_id: result.thread_id
      }
    rescue => e
      Rails.logger.error "Failed to send email: #{e.message}"
      Rails.logger.error "Error details: #{e.backtrace.first(5).join('\n')}"
      {
        success: false,
        error: e.message
      }
    end
  end

  private

  def create_email_message(to_email:, subject:, body:)
    # Get user's email address
    user_email = @user.email_address
    
    # Use the Mail gem to create a properly formatted email
    mail = Mail.new do
      from user_email
      to to_email
      subject subject
      body body
    end
    
    # Create Gmail message object
    message = Google::Apis::GmailV1::Message.new(
      raw: mail.to_s
    )
    
    message
  end

  def build_authorization
    identity = @user.omni_auth_identities.find_by(provider: "google_oauth2")
    return nil unless identity&.access_token

    auth = Google::Auth::UserRefreshCredentials.new(
      client_id: Rails.application.credentials.dig(:oauth, :google, :client_id),
      client_secret: Rails.application.credentials.dig(:oauth, :google, :client_secret),
      refresh_token: identity.refresh_token,
      access_token: identity.access_token
    )

    # Refresh token if expired
    if identity.expires_at && identity.expires_at < Time.current
      auth.refresh!
      identity.update!(
        access_token: auth.access_token,
        expires_at: Time.current + auth.expires_in.seconds
      )
    end

    auth
  rescue => e
    Rails.logger.error "Failed to build Gmail authorization: #{e.message}"
    nil
  end

  def extract_email_data(message)
    headers = message.payload.headers

    {
      gmail_id: message.id,
      thread_id: message.thread_id,
      subject: get_header_value(headers, "Subject"),
      from_email: get_header_value(headers, "From"),
      to_email: get_header_value(headers, "To"),
      cc_email: get_header_value(headers, "Cc"),
      bcc_email: get_header_value(headers, "Bcc"),
      received_at: parse_date(get_header_value(headers, "Date")),
      body: extract_body(message.payload),
      labels: message.label_ids&.join(",")
    }
  end

  def get_header_value(headers, name)
    header = headers.find { |h| h.name.downcase == name.downcase }
    header&.value
  end

  def parse_date(date_string)
    return nil unless date_string
    Time.parse(date_string)
  rescue
    nil
  end

  def extract_body(payload)
    return extract_body_from_parts(payload.parts) if payload.parts&.any?

    # Single part message
    if payload.body&.data
      payload.body.data
    else
      ""
    end
  rescue => e
    Rails.logger.error "Error extracting email body: #{e.message}"
    ""
  end

  def extract_body_from_parts(parts)
    # Look for text/plain first, then text/html
    text_part = find_part_by_mime_type(parts, "text/plain")
    html_part = find_part_by_mime_type(parts, "text/html")

    if text_part&.body&.data
      text_part.body.data
    elsif html_part&.body&.data
      # Strip HTML tags for plain text
      html_content = html_part.body.data
      html_content.gsub(/<[^>]*>/, " ").gsub(/\s+/, " ").strip
    else
      ""
    end
  end

  def find_part_by_mime_type(parts, mime_type)
    parts.each do |part|
      return part if part.mime_type == mime_type

      # Recursively search in nested parts
      if part.parts&.any?
        found = find_part_by_mime_type(part.parts, mime_type)
        return found if found
      end
    end
    nil
  end
end
