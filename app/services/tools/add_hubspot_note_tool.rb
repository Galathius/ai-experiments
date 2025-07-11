module Tools
  class AddHubspotNoteTool < BaseTool
    def self.openai_definition
      {
        type: "function",
        function: {
          name: tool_name,
          description: "Add a note to a HubSpot contact",
          parameters: {
            type: "object",
            properties: {
              contact_email: {
                type: "string",
                description: "Email of the contact to add note to"
              },
              note_content: {
                type: "string",
                description: "The note content to add"
              }
            },
            required: [ "contact_email", "note_content" ]
          }
        }
      }
    end
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
              note_content: params["note_content"],
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
      user.hubspot_contacts.find_by(email: params["contact_email"])
    end

    def create_hubspot_note(contact)
      # Use the new HubSpot service
      create_note_service = Hubspot::CreateNote.new(user)
      result = create_note_service.create(
        contact.hubspot_contact_id,
        params["note_content"]
      )

      unless result[:success]
        raise "Failed to create note in HubSpot: #{result[:error]}"
      end

      result[:local_note]
    rescue => e
      Rails.logger.error "Failed to create HubSpot note: #{e.message}"
      nil
    end
  end
end
