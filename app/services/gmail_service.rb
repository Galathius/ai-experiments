require "mail"

class GmailService
  def initialize(user)
    @user = user
    @gmail = Google::Apis::GmailV1::GmailService.new
    @gmail.authorization = build_authorization
  end

  def import_emails(batch_size: 100)
    return unless @gmail.authorization

    mailbox = @user.get_or_create_mailbox
    return if mailbox.syncing?

    begin
      mailbox.start_sync!
      total_imported = perform_incremental_sync(mailbox, batch_size)
      mailbox.complete_sync!
      total_imported
    rescue => e
      mailbox.fail_sync!(e.message)
      raise e
    end
  end

  def reset_and_import_all(batch_size: 100)
    return unless @gmail.authorization

    mailbox = @user.get_or_create_mailbox
    mailbox.reset_sync!
    import_emails(batch_size: batch_size)
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

  def perform_incremental_sync(mailbox, batch_size)
    total_imported = 0
    page_token = mailbox.next_page_token
    processed_count = 0

    sync_type = mailbox.initial_sync? ? "initial" : "incremental"
    Rails.logger.info "Starting #{sync_type} Gmail sync for user #{@user.id}"

    loop do
      # Get list of message IDs with pagination
      message_list = @gmail.list_user_messages(
        "me",
        max_results: batch_size,
        page_token: page_token,
        q: "-in:spam -in:trash" # Exclude spam and trash
      )

      break unless message_list.messages&.any?

      # Process batch of messages
      batch_imported = import_email_batch(message_list.messages)
      total_imported += batch_imported
      processed_count += message_list.messages.length

      Rails.logger.info "Gmail sync progress: #{processed_count} processed, #{total_imported} imported"

      # Update mailbox with current page token
      page_token = message_list.next_page_token
      mailbox.update!(next_page_token: page_token)

      # If no more pages, we've reached the end
      break unless page_token

      # Rate limiting: sleep between batches to avoid hitting API limits
      sleep(0.1)
    end

    Rails.logger.info "Gmail sync completed: #{total_imported} emails imported (#{sync_type})"
    total_imported
  end

  def import_email_batch(messages)
    emails_imported = 0
    mailbox = @user.get_or_create_mailbox

    messages.each do |message|
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

        # Trigger proactive analysis only for incremental syncs (not initial)
        if !mailbox.initial_sync?
          ProactiveEmailAnalysisJob.perform_later(@user.id, email.id)
          Rails.logger.debug "Triggered proactive analysis for new email: #{email.subject}"
        end

        emails_imported += 1
        Rails.logger.debug "Imported email: #{email.subject} (#{email.gmail_id})"

      rescue => e
        Rails.logger.error "Error importing email #{message.id}: #{e.message}"
        # Continue with next email instead of failing entire batch
        next
      end
    end

    emails_imported
  end

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
