module Hubspot
  class CreateNote < Base
    def create(contact_id, note_content, additional_properties = {})
      return { success: false, error: "No HubSpot connection" } unless client_available?

      begin
        # Create the note in HubSpot
        note_response = create_hubspot_note(note_content, additional_properties)
        return { success: false, error: "Failed to create note in HubSpot" } unless note_response

        # Associate the note with the contact
        association_result = associate_with_contact(note_response["id"], contact_id)
        
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
          association_success: association_result
        }
      rescue ::Hubspot::ApiError => e
        handle_api_error(e, "creating note")
        { success: false, error: e.message }
      rescue => e
        Rails.logger.error "Failed to create HubSpot note for user #{@user.id}: #{e.message}"
        { success: false, error: e.message }
      end
    end

    private

    def create_hubspot_note(note_content, additional_properties)
      properties = {
        "hs_note_body" => note_content,
        "hs_timestamp" => (Time.current.to_i * 1000).to_s
      }.merge(additional_properties)

      note_input = ::Hubspot::Crm::Objects::Notes::SimplePublicObjectInput.new(properties: properties)
      response = @client.crm.objects.notes.basic_api.create(note_input)
      
      response.to_hash
    rescue ::Hubspot::ApiError => e
      Rails.logger.error "Failed to create note in HubSpot: #{e.message}"
      nil
    end

    def associate_with_contact(note_id, contact_id)
      begin
        association_input = ::Hubspot::Crm::Objects::Notes::AssociationSpec.new(
          association_category: "HUBSPOT_DEFINED",
          association_type_id: 202
        )

        @client.crm.objects.notes.associations_api.create(
          note_id,
          "contacts",
          contact_id,
          association_input
        )
        
        true
      rescue ::Hubspot::ApiError => e
        Rails.logger.error "Failed to associate note #{note_id} with contact #{contact_id}: #{e.message}"
        false
      end
    end

    def save_to_local_database(hubspot_data, contact_id)
      # Find the local contact
      local_contact = @user.hubspot_contacts.find_by(hubspot_contact_id: contact_id)

      # Create new local note record
      @user.hubspot_notes.create!(
        hubspot_note_id: hubspot_data["id"],
        content: hubspot_data.dig("properties", "hs_note_body"),
        created_date: parse_hubspot_timestamp(hubspot_data.dig("properties", "hs_timestamp")),
        hubspot_contact: local_contact
      )
    rescue => e
      Rails.logger.error "Failed to save HubSpot note locally: #{e.message}"
      nil
    end

    def parse_hubspot_timestamp(timestamp_string)
      return Time.current unless timestamp_string.present?
      
      # HubSpot timestamps are often in milliseconds
      if timestamp_string.to_i > 1_000_000_000_000
        Time.at(timestamp_string.to_i / 1000)
      else
        Time.at(timestamp_string.to_i)
      end
    rescue => e
      Rails.logger.error "Failed to parse HubSpot timestamp #{timestamp_string}: #{e.message}"
      Time.current
    end
  end
end
