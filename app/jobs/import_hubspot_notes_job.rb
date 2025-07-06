class ImportHubspotNotesJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    hubspot_identity = user.hubspot_identity
    
    return unless hubspot_identity

    hubspot_service = HubspotService.new(hubspot_identity.access_token, hubspot_identity)
    
    after = nil
    imported_count = 0
    
    loop do
      response = hubspot_service.get_notes(limit: 100, after: after)
      break unless response
      
      notes = response['results'] || []
      break if notes.empty?
      
      notes.each do |note_data|
        import_note(user, note_data)
        imported_count += 1
      end
      
      # Check for next page
      paging = response['paging']
      break unless paging && paging['next']
      
      after = paging['next']['after']
    end
    
    Rails.logger.info "Imported #{imported_count} HubSpot notes for user #{user.id}"
  end

  private

  def import_note(user, note_data)
    properties = note_data['properties'] || {}
    associations = note_data['associations'] || {}
    
    note = user.hubspot_notes.find_or_initialize_by(
      hubspot_note_id: note_data['id']
    )
    
    # Get the contact associations for this note
    contact_id = nil
    hubspot_contact = nil
    
    if associations['contacts'] && associations['contacts']['results']&.any?
      contact_id = associations['contacts']['results'].first['id']
      hubspot_contact = user.hubspot_contacts.find_by(hubspot_contact_id: contact_id)
    end
    
    note.assign_attributes(
      hubspot_contact_id: contact_id,
      hubspot_contact: hubspot_contact,
      content: properties['hs_note_body'] || '',
      created_date: parse_hubspot_date(properties['hs_createdate'])
    )
    
    if note.save && note.content.present?
      # Generate embedding
      GenerateEmbeddingJob.perform_later(note)
    end
    
    Rails.logger.info "Imported note #{note_data['id']} linked to contact #{contact_id || 'none'}"
  end

  def parse_hubspot_date(date_string)
    return nil unless date_string.present?
    
    begin
      if date_string.include?('T')
        DateTime.parse(date_string)
      else
        Time.at(date_string.to_i / 1000)
      end
    rescue
      nil
    end
  end
end