module Hubspot
  class CreateContact < Base
    def create(properties)
      return { success: false, error: "No HubSpot connection" } unless client_available?

      begin
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
      rescue ::Hubspot::ApiError => e
        handle_api_error(e, "creating contact")
        { success: false, error: e.message }
      rescue => e
        Rails.logger.error "Failed to create HubSpot contact for user #{@user.id}: #{e.message}"
        { success: false, error: e.message }
      end
    end

    def create_from_email(email_address, additional_properties = {})
      # Extract name from email if not provided
      properties = {
        "email" => email_address
      }.merge(additional_properties)

      # Try to extract first name from email if not provided
      if properties["firstname"].blank?
        username = email_address.split("@").first
        if username.include?(".")
          name_parts = username.split(".")
          properties["firstname"] = name_parts.first.titleize
          properties["lastname"] = name_parts.last.titleize if name_parts.length > 1
        else
          properties["firstname"] = username.titleize
        end
      end

      create(properties)
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