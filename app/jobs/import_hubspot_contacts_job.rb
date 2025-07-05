class ImportHubspotContactsJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    hubspot_identity = user.hubspot_identity
    
    return unless hubspot_identity

    hubspot_service = HubspotService.new(hubspot_identity.access_token)
    
    after = nil
    imported_count = 0
    
    loop do
      response = hubspot_service.get_contacts(limit: 100, after: after)
      break unless response
      
      contacts = response['results'] || []
      break if contacts.empty?
      
      contacts.each do |contact_data|
        import_contact(user, contact_data)
        imported_count += 1
      end
      
      # Check for next page
      paging = response['paging']
      break unless paging && paging['next']
      
      after = paging['next']['after']
    end
    
    Rails.logger.info "Imported #{imported_count} HubSpot contacts for user #{user.id}"
  end

  private

  def import_contact(user, contact_data)
    properties = contact_data['properties'] || {}
    
    contact = user.hubspot_contacts.find_or_initialize_by(
      hubspot_contact_id: contact_data['id']
    )
    
    contact.assign_attributes(
      first_name: properties['firstname'],
      last_name: properties['lastname'],
      email: properties['email'],
      company: properties['company'],
      phone: properties['phone'],
      notes: properties['notes']
    )
    
    if contact.save
      # Generate embedding
      GenerateEmbeddingJob.perform_later(contact)
    end
  end
end