class ImportHubspotNotesJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    hubspot_identity = user.hubspot_identity
    
    return unless hubspot_identity

    hubspot_service = HubspotService.new(hubspot_identity.access_token)
    
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
    
    note = user.hubspot_notes.find_or_initialize_by(
      hubspot_note_id: note_data['id']
    )
    
    # Find associated contact if available
    contact_id = properties['hs_associated_object_id']
    hubspot_contact = user.hubspot_contacts.find_by(hubspot_contact_id: contact_id) if contact_id
    
    note.assign_attributes(
      hubspot_contact: hubspot_contact,
      content: properties['hs_note_body'],
      created_date: properties['hs_created_date'] ? Time.parse(properties['hs_created_date']) : nil
    )
    
    if note.save
      # Generate embedding
      GenerateEmbeddingJob.perform_later(note)
    end
  end
end