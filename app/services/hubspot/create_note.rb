module Hubspot
  class CreateNote < Base
    def create(contact_id, note_content, additional_properties = {})
      with_token_refresh do
        # Create the note in HubSpot with contact association
        note_response = create_hubspot_note_with_contact(note_content, contact_id, additional_properties)
        return { success: false, error: "Failed to create note in HubSpot" } unless note_response

        {
          success: true,
          hubspot_data: note_response
        }
      end
    rescue => e
      Rails.logger.error "Failed to create HubSpot note for user #{@user.id}: #{e.message}"
      { success: false, error: e.message }
    end

    private

    def create_hubspot_note_with_contact(note_content, contact_id, additional_properties)
      # Use the simple approach that was working before
      response = @client.create_note_with_contact(note_content, contact_id)
      response
    rescue => e
      Rails.logger.error "Failed to create note in HubSpot: #{e.message}"
      nil
    end

    def associate_with_contact(note_id, contact_id)
      begin
        @client.associate_note_with_contact(note_id, contact_id)
        true
      rescue HubspotApiError => e
        Rails.logger.error "Failed to associate note #{note_id} with contact #{contact_id}: #{e.message}"
        false
      end
    end

  end
end
