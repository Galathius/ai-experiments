class AutoSyncService
  SYNC_THRESHOLD = 30.minutes # Don't sync if data is fresher than this
  
  def self.sync_user_data(user, force: false)
    new(user).sync_all(force: force)
  end
  
  def initialize(user)
    @user = user
  end
  
  def sync_all(force: false)
    results = {}
    
    # Sync Google data if connected
    if @user.google_identity
      results[:google] = sync_google_data(force: force)
    end
    
    # Sync HubSpot data if connected
    if @user.hubspot_identity
      results[:hubspot] = sync_hubspot_data(force: force)
    end
    
    results
  end
  
  private
  
  def sync_google_data(force: false)
    return { skipped: "No Google connection" } unless @user.google_identity
    
    # Check if sync is needed
    last_email_sync = @user.emails.maximum(:updated_at)
    last_calendar_sync = @user.calendar_events.maximum(:updated_at)
    
    needs_email_sync = force || last_email_sync.nil? || last_email_sync < SYNC_THRESHOLD.ago
    needs_calendar_sync = force || last_calendar_sync.nil? || last_calendar_sync < SYNC_THRESHOLD.ago
    
    results = {}
    
    if needs_email_sync
      results[:emails] = sync_emails
    else
      results[:emails] = { skipped: "Data is fresh" }
    end
    
    if needs_calendar_sync
      results[:calendar] = sync_calendar_events
    else
      results[:calendar] = { skipped: "Data is fresh" }
    end
    
    results
  end
  
  def sync_hubspot_data(force: false)
    return { skipped: "No HubSpot connection" } unless @user.hubspot_identity
    
    # Check if sync is needed
    last_contact_sync = @user.hubspot_contacts.maximum(:updated_at)
    last_note_sync = @user.hubspot_notes.maximum(:updated_at)
    
    needs_contact_sync = force || last_contact_sync.nil? || last_contact_sync < SYNC_THRESHOLD.ago
    needs_note_sync = force || last_note_sync.nil? || last_note_sync < SYNC_THRESHOLD.ago
    
    results = {}
    
    if needs_contact_sync
      results[:contacts] = sync_hubspot_contacts
    else
      results[:contacts] = { skipped: "Data is fresh" }
    end
    
    if needs_note_sync
      results[:notes] = sync_hubspot_notes
    else
      results[:notes] = { skipped: "Data is fresh" }
    end
    
    results
  end
  
  def sync_emails
    begin
      service = GmailService.new(@user)
      imported_count = service.import_emails(limit: 100)
      
      { success: true, imported: imported_count, total_checked: imported_count }
    rescue => e
      Rails.logger.error "Email sync failed for user #{@user.id}: #{e.message}"
      { success: false, error: e.message }
    end
  end
  
  def sync_calendar_events
    begin
      service = CalendarService.new(@user)
      imported_count = service.import_events(limit: 100)
      
      { success: true, imported: imported_count, total_checked: imported_count }
    rescue => e
      Rails.logger.error "Calendar sync failed for user #{@user.id}: #{e.message}"
      { success: false, error: e.message }
    end
  end
  
  def sync_hubspot_contacts
    begin
      service = HubspotService.new(@user.hubspot_identity.access_token, @user.hubspot_identity)
      contacts_data = service.get_contacts(limit: 100)
      imported_count = 0
      
      contacts_data.each do |contact_data|
        # Import contact logic would go here
        # For now, just count existing ones to avoid duplication errors
        existing_contact = @user.hubspot_contacts.find_by(hubspot_contact_id: contact_data['id'])
        unless existing_contact
          # Create new contact record
          @user.hubspot_contacts.create!(
            hubspot_contact_id: contact_data['id'],
            email: contact_data.dig('properties', 'email'),
            first_name: contact_data.dig('properties', 'firstname'),
            last_name: contact_data.dig('properties', 'lastname'),
            company: contact_data.dig('properties', 'company'),
            phone: contact_data.dig('properties', 'phone'),
            contact_data: contact_data
          )
          imported_count += 1
        end
      end
      
      { success: true, imported: imported_count, total_checked: contacts_data.size }
    rescue => e
      Rails.logger.error "HubSpot contacts sync failed for user #{@user.id}: #{e.message}"
      { success: false, error: e.message }
    end
  end
  
  def sync_hubspot_notes
    begin
      service = HubspotService.new(@user.hubspot_identity.access_token, @user.hubspot_identity)
      notes_data = service.get_notes(limit: 100)
      imported_count = 0
      
      notes_data.each do |note_data|
        # Import note logic would go here
        # For now, just count existing ones to avoid duplication errors
        existing_note = @user.hubspot_notes.find_by(hubspot_note_id: note_data['id'])
        unless existing_note
          # Create new note record
          @user.hubspot_notes.create!(
            hubspot_note_id: note_data['id'],
            content: note_data.dig('properties', 'hs_note_body'),
            created_date: Time.parse(note_data.dig('properties', 'hs_timestamp')),
            note_data: note_data
          )
          imported_count += 1
        end
      end
      
      { success: true, imported: imported_count, total_checked: notes_data.size }
    rescue => e
      Rails.logger.error "HubSpot notes sync failed for user #{@user.id}: #{e.message}"
      { success: false, error: e.message }
    end
  end
end