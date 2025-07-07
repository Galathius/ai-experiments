class HubspotController < ApplicationController
  before_action :authenticate

  def index
    @hubspot_identity = Current.user.hubspot_identity
    @contacts_count = Current.user.hubspot_contacts.count
    @notes_count = Current.user.hubspot_notes.count
  end

  def disconnect
    hubspot_identity = Current.user.hubspot_identity
    if hubspot_identity
      # Delete associated data
      Current.user.hubspot_contacts.destroy_all
      Current.user.hubspot_notes.destroy_all
      hubspot_identity.destroy
      redirect_to hubspot_path, notice: "HubSpot account disconnected successfully."
    else
      redirect_to hubspot_path, alert: "No HubSpot account connected."
    end
  end



  private

  def authenticate
    redirect_to new_session_path unless authenticated?
  end
end
