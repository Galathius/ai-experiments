module Hubspot
  class CreateContact < Base
    def create(properties)
      with_token_refresh do
        response = @client.create_contact(properties)
        
        {
          success: true,
          hubspot_data: response
        }
      end
    rescue => e
      Rails.logger.error "Failed to create HubSpot contact for user #{@user.id}: #{e.message}"
      { success: false, error: e.message }
    end
  end
end
