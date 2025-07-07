module Hubspot
  class CreateNote < Base
    def create(contact_id, note_content, additional_properties = {})
      with_token_refresh do
        # Create the note in HubSpot with contact association
        note_response = create_hubspot_note_with_contact(note_content, contact_id, additional_properties)
        return { success: false, error: "Failed to create note in HubSpot" } unless note_response

        # Save to local database
        local_note = save_to_local_database(note_response, contact_id)
        
        # Generate embedding for the new note
        if local_note
          EmbeddingService.generate_embedding_for(local_note)
        end

        {
          success: true,
          hubspot_data: note_response,
          local_note: local_note,
          association_success: true  # Association created during note creation
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

    def save_to_local_database(hubspot_data, contact_id)
      # Find the local contact
      local_contact = @user.hubspot_contacts.find_by(hubspot_contact_id: contact_id)

      # Extract data from CRM objects API response (back to original format)
      note_id = hubspot_data["id"]
      note_body = hubspot_data.dig("properties", "hs_note_body")
      created_timestamp = hubspot_data.dig("properties", "hs_timestamp")

      # Create new local note record
      @user.hubspot_notes.create!(
        hubspot_note_id: note_id,
        content: note_body,
        created_date: parse_hubspot_timestamp(created_timestamp),
        hubspot_contact: local_contact
      )
    rescue => e
      Rails.logger.error "Failed to save HubSpot note locally: #{e.message}"
      Rails.logger.error "HubSpot data was: #{hubspot_data.inspect}"
      nil
    end

    def parse_hubspot_timestamp(timestamp_string)
      return Time.current unless timestamp_string.present?
      
      timestamp_int = timestamp_string.to_i
      
      # Skip invalid timestamps (0 or very small numbers)
      return Time.current if timestamp_int <= 0
      
      # HubSpot timestamps are typically in milliseconds since epoch
      # Check if it looks like milliseconds (13+ digits) vs seconds (10 digits)
      if timestamp_int > 1_000_000_000_000  # 13+ digits = milliseconds
        Time.at(timestamp_int / 1000.0)
      elsif timestamp_int > 1_000_000_000   # 10+ digits = seconds  
        Time.at(timestamp_int)
      else
        # For anything else, use current time as fallback
        Rails.logger.warn "Unusual HubSpot timestamp format: #{timestamp_string}, using current time"
        Time.current
      end
    rescue => e
      Rails.logger.error "Failed to parse HubSpot timestamp #{timestamp_string}: #{e.message}"
      Time.current
    end
  end
end
