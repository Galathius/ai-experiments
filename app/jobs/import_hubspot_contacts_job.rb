class ImportHubspotContactsJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    return unless user.hubspot_identity

    begin
      sync_service = Hubspot::SyncContacts.new(user)
      result = sync_service.sync_all
      
      if result[:success]
        # Mark initial sync as complete
        user.update!(hubspot_contacts_initial_sync_complete: true)
        Rails.logger.info "Imported #{result[:imported]} HubSpot contacts for user #{user.id}"
      else
        Rails.logger.error "HubSpot contacts import failed for user #{user.id}: #{result[:error]}"
      end
    rescue => e
      Rails.logger.error "HubSpot contacts import job failed for user #{user.id}: #{e.message}"
      raise e
    end
  end
end
