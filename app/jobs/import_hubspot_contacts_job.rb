class ImportHubspotContactsJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    hubspot_identity = user.hubspot_identity
    
    return unless hubspot_identity

    hubspot_service = HubspotService.new(hubspot_identity.access_token, hubspot_identity)
    
    after = nil
    imported_count = 0
    
    loop do
      response = hubspot_service.get_contacts(limit: 100, after: after)
      break unless response
      
      contacts = response['results'] || []
      break if contacts.empty?
      
      contacts.each do |contact_data|
        import_contact(user, contact_data, hubspot_service)
        imported_count += 1
      end
      
      # Check for next page
      paging = response['paging']
      break unless paging && paging['next']
      
      after = paging['next']['after']
    end
    
    Rails.logger.info "Imported #{imported_count} HubSpot contacts for user #{user.id}"
  end

  private

  def import_contact(user, contact_data, hubspot_service)
    properties = contact_data['properties'] || {}
    
    contact = user.hubspot_contacts.find_or_initialize_by(
      hubspot_contact_id: contact_data['id']
    )
    
    contact.assign_attributes(
      first_name: properties['firstname'],
      last_name: properties['lastname'],
      email: properties['email'],
      company: properties['company'],
      phone: properties['phone']
    )
    
    # Fetch and store notes for this contact
    begin
      Rails.logger.info "Fetching notes for contact #{contact_data['id']}"
      notes_data = hubspot_service.get_contact_notes(contact_data['id'])
      Rails.logger.info "Found #{notes_data.length} notes for contact #{contact_data['id']}"
      
      # Combine all notes into a single text field
      if notes_data.any?
        notes_text = notes_data.map do |note|
          note_properties = note['properties'] || {}
          Rails.logger.info "Note properties: #{note_properties.inspect}"
          
          body = note_properties['hs_note_body'] || ''
          # Try different timestamp properties
          timestamp = note_properties['hs_timestamp'] || note_properties['hs_createdate'] || ''
          
          # Format: "Date: Note content"
          if timestamp.present? && body.present?
            begin
              # Handle ISO date format from hs_createdate
              if timestamp.include?('T')
                date = DateTime.parse(timestamp).strftime('%Y-%m-%d')
              else
                # Handle millisecond timestamp from hs_timestamp
                date = Time.at(timestamp.to_i / 1000).strftime('%Y-%m-%d')
              end
              "#{date}: #{body}"
            rescue
              body
            end
          else
            body
          end
        end.compact.reject(&:empty?).join("\n\n")
        
        contact.notes = notes_text if notes_text.present?
      end
    rescue => e
      Rails.logger.error "Failed to fetch notes for contact #{contact_data['id']}: #{e.message}"
      Rails.logger.error "Error details: #{e.backtrace.first(5).join(', ')}"
      # Continue without notes
    end
    
    if contact.save
      # Generate embedding
      GenerateEmbeddingJob.perform_later(contact)
    end
  end
end