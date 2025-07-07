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
      imported_count = service.import_emails

      { success: true, imported: imported_count, total_checked: imported_count }
    rescue => e
      Rails.logger.error "Email sync failed for user #{@user.id}: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def sync_calendar_events
    begin
      service = CalendarService.new(@user)
      imported_count = service.import_events

      { success: true, imported: imported_count, total_checked: imported_count }
    rescue => e
      Rails.logger.error "Calendar sync failed for user #{@user.id}: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def sync_hubspot_contacts
    begin
      service = Hubspot::SyncContacts.new(@user)
      result = service.sync(limit: 100)
      
      if result[:success]
        { success: true, imported: result[:imported], total_checked: result[:total_checked] }
      else
        { success: false, error: result[:error] }
      end
    rescue => e
      Rails.logger.error "HubSpot contacts sync failed for user #{@user.id}: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def sync_hubspot_notes
    begin
      service = Hubspot::SyncNotes.new(@user)
      result = service.sync(limit: 100)
      
      if result[:success]
        { success: true, imported: result[:imported], total_checked: result[:total_checked] }
      else
        { success: false, error: result[:error] }
      end
    rescue => e
      Rails.logger.error "HubSpot notes sync failed for user #{@user.id}: #{e.message}"
      { success: false, error: e.message }
    end
  end
end
