module Hubspot
  class CreateContact < Base
    def create(properties)
      with_token_refresh do
        contact_input = ::Hubspot::Crm::Contacts::SimplePublicObjectInput.new(properties: properties)
        response = @client.crm.contacts.basic_api.create(contact_input)
        
        # Also save to local database
        local_contact = save_to_local_database(response.to_hash)
        
        # Generate embedding for the new contact
        if local_contact
          EmbeddingService.generate_embedding_for(local_contact)
        end

        {
          success: true,
          hubspot_data: response.to_hash,
          local_contact: local_contact
        }
      end
    rescue => e
      Rails.logger.error "Failed to create HubSpot contact for user #{@user.id}: #{e.message}"
      { success: false, error: e.message }
    end

    private

    def save_to_local_database(hubspot_data)
      # Check if contact already exists locally
      existing_contact = @user.hubspot_contacts.find_by(hubspot_contact_id: hubspot_data["id"])
      return existing_contact if existing_contact

      # Create new local contact record
      @user.hubspot_contacts.create!(
        hubspot_contact_id: hubspot_data["id"],
        email: hubspot_data.dig("properties", "email"),
        first_name: hubspot_data.dig("properties", "firstname"),
        last_name: hubspot_data.dig("properties", "lastname"),
        company: hubspot_data.dig("properties", "company"),
        phone: hubspot_data.dig("properties", "phone")
      )
    rescue => e
      Rails.logger.error "Failed to save HubSpot contact locally: #{e.message}"
      nil
    end
  end
end
