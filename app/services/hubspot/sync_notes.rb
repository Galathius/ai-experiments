module Hubspot
  class SyncNotes < Base
    def sync(limit: 100, after: nil)
      with_token_refresh do
        # Get notes from HubSpot
        notes_response = fetch_notes(limit: limit, after: after)
        return { success: false, error: "Failed to fetch notes" } unless notes_response

        notes_data = notes_response["results"] || []
        imported_count = 0

        notes_data.each do |note_data|
          if import_note(note_data)
            imported_count += 1
          end
        end

        # Generate embeddings for newly imported notes
        generate_embeddings_for_new_notes

        {
          success: true,
          imported: imported_count,
          total_checked: notes_data.size,
          paging: notes_response["paging"]
        }
      end
    rescue => e
      Rails.logger.error "HubSpot notes sync failed for user #{@user.id}: #{e.message}"
      { success: false, error: e.message }
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

    def fetch_notes(limit:, after: nil)
      properties = ["hs_note_body", "hs_timestamp", "hs_createdate", "hs_lastmodifieddate"]
      associations = ["contacts"]
      
      response = @client.get_notes(
        limit: limit, 
        after: after, 
        properties: properties, 
        associations: associations
      )
      response
    rescue => e
      handle_api_error(e, "fetching notes")
    end

    def import_note(note_data)
      # Get note ID (try both symbol and string keys)
      note_id = note_data[:id] || note_data["id"]
      
      # Skip if note ID is missing
      if note_id.blank?
        Rails.logger.warn "Skipping note with missing ID: #{note_data}"
        return false
      end

      # Skip if already imported
      existing_note = @user.hubspot_notes.find_by(hubspot_note_id: note_id)
      return false if existing_note

      # Get properties (try both symbol and string keys)
      properties = note_data[:properties] || note_data["properties"] || {}

      # Skip if note content is blank
      content = properties["hs_note_body"]
      if content.blank?
        Rails.logger.debug "Skipping note #{note_id} with empty content"
        return false
      end

      # Find associated contact if available
      associated_contact = find_associated_contact(note_data)

      # Create new note record
      note = @user.hubspot_notes.build(
        hubspot_note_id: note_id,
        content: content,
        created_date: parse_hubspot_date(properties["hs_timestamp"]),
        hubspot_contact: associated_contact
      )

      unless note.save
        Rails.logger.error "Validation errors for note #{note_id}: #{note.errors.full_messages.join(', ')}"
        return false
      end

      Rails.logger.debug "Imported HubSpot note: #{note_id}"
      true
    rescue => e
      note_id = note_data[:id] || note_data["id"] || "unknown"
      Rails.logger.error "Failed to import note #{note_id}: #{e.message}"
      Rails.logger.error "Note data: #{note_data.inspect}"
      false
    end

    def find_associated_contact(note_data)
      # Look for contact associations in the note data
      associations = note_data.dig("associations", "contacts", "results")
      return nil unless associations&.any?

      contact_id = associations.first["id"]
      @user.hubspot_contacts.find_by(hubspot_contact_id: contact_id)
    end

    def parse_hubspot_date(timestamp_string)
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
      Rails.logger.error "Failed to parse HubSpot date #{timestamp_string}: #{e.message}"
      Time.current
    end

    def generate_embeddings_for_new_notes
      # Generate embeddings for notes that don't have them yet
      notes_without_embeddings = @user.hubspot_notes
                                      .left_joins(:embedding)
                                      .where(embeddings: { id: nil })

      notes_without_embeddings.find_each do |note|
        EmbeddingService.generate_embedding_for(note)
      rescue => e
        Rails.logger.error "Failed to generate embedding for note #{note.id}: #{e.message}"
      end
    end
  end
end
