module Tools
  class CreateHubspotContactTool < BaseTool
    def self.openai_definition
      {
        type: "function",
        function: {
          name: tool_name,
          description: "Create a new contact in HubSpot",
          parameters: {
            type: "object",
            properties: {
              email: {
                type: "string",
                description: "Contact's email address"
              },
              first_name: {
                type: "string",
                description: "Contact's first name"
              },
              last_name: {
                type: "string",
                description: "Contact's last name"
              },
              company: {
                type: "string",
                description: "Contact's company name (optional)"
              },
              phone: {
                type: "string",
                description: "Contact's phone number (optional)"
              },
              job_title: {
                type: "string",
                description: "Contact's job title (optional)"
              }
            },
            required: ["email", "first_name"]
          }
        }
      }
    end

    def execute
      validate_required_params(:email, :first_name)
      validate_hubspot_connection

      begin
        # Build properties hash
        properties = {
          "email" => params["email"],
          "firstname" => params["first_name"]
        }
        
        # Add optional properties if provided
        properties["lastname"] = params["last_name"] if params["last_name"].present?
        properties["company"] = params["company"] if params["company"].present?
        properties["phone"] = params["phone"] if params["phone"].present?
        properties["jobtitle"] = params["job_title"] if params["job_title"].present?

        # Create contact using the service
        create_contact_service = Hubspot::CreateContact.new(user)
        result = create_contact_service.create(properties)

        if result[:success]
          success_response(
            "Contact '#{params['first_name']} #{params['last_name']}' created successfully in HubSpot",
            {
              contact_id: result[:hubspot_data]["id"],
              email: params["email"],
              first_name: params["first_name"],
              last_name: params["last_name"],
              company: params["company"],
              hubspot_url: "https://app.hubspot.com/contacts/#{result[:hubspot_data]['id']}"
            }
          )
        else
          error_response("Failed to create contact in HubSpot: #{result[:error]}")
        end
      rescue => e
        Rails.logger.error "CreateHubspotContactTool error: #{e.message}"
        error_response("Error creating HubSpot contact: #{e.message}")
      end
    end

    private

    def validate_hubspot_connection
      unless user.hubspot_identity&.access_token.present?
        raise ArgumentError, "HubSpot connection required. Please connect your HubSpot account first."
      end
    end
  end
end