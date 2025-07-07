require "hubspot-api-client"

class HubspotService
  def initialize(access_token)
    @client = Hubspot::Client.new(access_token: access_token)
  end

  def get_contacts(limit: 100, after: nil)
    begin
      opts = { limit: limit }
      opts[:after] = after if after

      response = @client.crm.contacts.basic_api.get_page(opts)

      {
        "results" => response.results.map(&:to_hash),
        "paging" => response.paging&.to_hash
      }
    rescue Hubspot::ApiError => e
      handle_api_error(e, "getting contacts")
    end
  end

  def get_contact(contact_id)
    begin
      response = @client.crm.contacts.basic_api.get_by_id(contact_id)
      response.to_hash
    rescue Hubspot::ApiError => e
      handle_api_error(e, "getting contact #{contact_id}")
    end
  end

  def create_contact(properties)
    begin
      contact_input = Hubspot::Crm::Contacts::SimplePublicObjectInput.new(properties: properties)
      response = @client.crm.contacts.basic_api.create(contact_input)
      response.to_hash
    rescue Hubspot::ApiError => e
      handle_api_error(e, "creating contact")
    end
  end

  def get_notes(limit: 100, after: nil)
    begin
      opts = {
        limit: limit,
        properties: [ "hs_note_body", "hs_timestamp", "hs_createdate", "hs_lastmodifieddate" ],
        associations: [ "contacts" ]
      }
      opts[:after] = after if after

      response = @client.crm.objects.notes.basic_api.get_page(opts)

      {
        "results" => response.results.map(&:to_hash),
        "paging" => response.paging&.to_hash
      }
    rescue Hubspot::ApiError => e
      handle_api_error(e, "getting notes")
    end
  end

  def get_contact_notes(contact_id, limit: 100)
    begin
      # Get note associations for the contact
      response = @client.crm.contacts.associations_api.get_all(contact_id, "notes", { limit: limit })
      note_ids = response.results.map(&:id)

      # Fetch actual note content for each note ID
      notes = []
      note_ids.each do |note_id|
        note_data = get_note(note_id)
        notes << note_data if note_data
      end

      notes
    rescue Hubspot::ApiError => e
      handle_api_error(e, "getting contact notes for #{contact_id}")
      []
    end
  end

  def get_note(note_id)
    begin
      response = @client.crm.objects.notes.basic_api.get_by_id(
        note_id,
        properties: [ "hs_note_body", "hs_timestamp", "hs_createdate" ]
      )
      response.to_hash
    rescue Hubspot::ApiError => e
      handle_api_error(e, "getting note #{note_id}")
    end
  end

  def create_note(contact_id, note_content)
    begin
      # Create the note
      note_input = Hubspot::Crm::Objects::Notes::SimplePublicObjectInput.new(
        properties: {
          "hs_note_body" => note_content,
          "hs_timestamp" => (Time.current.to_i * 1000).to_s
        }
      )

      note_response = @client.crm.objects.notes.basic_api.create(note_input)

      # Associate the note with the contact
      association_input = Hubspot::Crm::Objects::Notes::AssociationSpec.new(
        association_category: "HUBSPOT_DEFINED",
        association_type_id: 202
      )

      @client.crm.objects.notes.associations_api.create(
        note_response.id,
        "contacts",
        contact_id,
        association_input
      )

      note_response.to_hash
    rescue Hubspot::ApiError => e
      handle_api_error(e, "creating note for contact #{contact_id}")
    end
  end

  private

  def handle_api_error(error, operation)
    Rails.logger.error "HubSpot API error during #{operation}: #{error.code} #{error.message}"
    Rails.logger.error "Response body: #{error.response_body}" if error.respond_to?(:response_body)
    nil
  end
end
