module Tools
  class AddHubspotNoteTool < BaseTool
    def execute
      validate_required_params(:contact_email, :note_content)
      validate_hubspot_connection
      
      begin
        contact = find_contact_by_email
        unless contact
          return error_response("Contact with email #{params['contact_email']} not found")
        end
        
        note = create_hubspot_note(contact)
        
        if note
          success_response(
            "Note added to #{contact.full_name || params['contact_email']}",
            {
              contact_name: contact.full_name,
              contact_email: contact.email,
              note_content: params['note_content'],
              note_id: note.id
            }
          )
        else
          error_response("Failed to create note")
        end
      rescue => e
        Rails.logger.error "AddHubspotNoteTool error: #{e.message}"
        error_response("Error adding HubSpot note: #{e.message}")
      end
    end
    
    private
    
    def validate_hubspot_connection
      unless user.hubspot_identity&.access_token.present?
        raise ArgumentError, "HubSpot connection required. Please connect your HubSpot account first."
      end
    end
    
    def find_contact_by_email
      user.hubspot_contacts.find_by(email: params['contact_email'])
    end
    
    def create_hubspot_note(contact)
      # Create a local note record
      note = user.hubspot_notes.create!(
        hubspot_contact: contact,
        hubspot_contact_id: contact.hubspot_contact_id,
        content: params['note_content'],
        created_date: Time.current,
        hubspot_note_id: "local_note_#{Time.current.to_i}"
      )
      
      # Generate embedding for the note
      GenerateEmbeddingJob.perform_later(note)
      
      note
    rescue => e
      Rails.logger.error "Failed to create HubSpot note: #{e.message}"
      nil
    end
  end
end