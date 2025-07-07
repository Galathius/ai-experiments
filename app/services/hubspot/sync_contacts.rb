module Hubspot
  class SyncContacts < Base
    def sync(limit: 100, after: nil)
      return { success: false, error: "No HubSpot connection" } unless client_available?

      begin
        # Get contacts from HubSpot
        contacts_response = fetch_contacts(limit: limit, after: after)
        return { success: false, error: "Failed to fetch contacts" } unless contacts_response

        contacts_data = contacts_response["results"] || []
        imported_count = 0

        contacts_data.each do |contact_data|
          if import_contact(contact_data)
            imported_count += 1
          end
        end

        # Generate embeddings for newly imported contacts
        generate_embeddings_for_new_contacts

        {
          success: true,
          imported: imported_count,
          total_checked: contacts_data.size,
          paging: contacts_response["paging"]
        }
      rescue => e
        Rails.logger.error "HubSpot contacts sync failed for user #{@user.id}: #{e.message}"
        { success: false, error: e.message }
      end
    end

    def sync_all
      results = { imported: 0, total_checked: 0 }
      after = nil

      loop do
        batch_result = sync(limit: 100, after: after)
        
        unless batch_result[:success]
          return batch_result
        end

        results[:imported] += batch_result[:imported]
        results[:total_checked] += batch_result[:total_checked]

        # Check if there are more pages
        paging = batch_result[:paging]
        after = paging&.dig("next", "after")
        break unless after

        # Rate limiting
        sleep(0.1)
      end

      results[:success] = true
      results
    end

    private

    def fetch_contacts(limit:, after: nil)
      opts = { limit: limit }
      opts[:after] = after if after

      response = @client.crm.contacts.basic_api.get_page(opts)

      {
        "results" => response.results.map(&:to_hash),
        "paging" => response.paging&.to_hash
      }
    rescue => e
      handle_api_error(e, "fetching contacts")
    end

    def import_contact(contact_data)
      # Get contact ID (try both symbol and string keys)
      contact_id = contact_data[:id] || contact_data["id"]
      
      # Skip if contact ID is missing
      if contact_id.blank?
        Rails.logger.warn "Skipping contact with missing ID: #{contact_data}"
        return false
      end

      # Skip if already imported
      existing_contact = @user.hubspot_contacts.find_by(hubspot_contact_id: contact_id)
      return false if existing_contact

      # Get properties (try both symbol and string keys)
      properties = contact_data[:properties] || contact_data["properties"] || {}

      # Create new contact record
      contact = @user.hubspot_contacts.build(
        hubspot_contact_id: contact_id,
        email: properties["email"],
        first_name: properties["firstname"],
        last_name: properties["lastname"],
        company: properties["company"],
        phone: properties["phone"]
      )

      unless contact.save
        Rails.logger.error "Validation errors for contact #{contact_id}: #{contact.errors.full_messages.join(', ')}"
        return false
      end

      Rails.logger.debug "Imported HubSpot contact: #{contact_id} (#{contact.full_name})"
      true
    rescue => e
      contact_id = contact_data[:id] || contact_data["id"] || "unknown"
      Rails.logger.error "Failed to import contact #{contact_id}: #{e.message}"
      Rails.logger.error "Contact data: #{contact_data.inspect}"
      false
    end

    def generate_embeddings_for_new_contacts
      # Generate embeddings for contacts that don't have them yet
      contacts_without_embeddings = @user.hubspot_contacts
                                         .left_joins(:embedding)
                                         .where(embeddings: { id: nil })

      contacts_without_embeddings.find_each do |contact|
        EmbeddingService.generate_embedding_for(contact)
      rescue => e
        Rails.logger.error "Failed to generate embedding for contact #{contact.id}: #{e.message}"
      end
    end
  end
end
