class HubspotContactsController < ApplicationController
  before_action :authenticate

  def index
    @contacts = Current.user.hubspot_contacts.order(:first_name, :last_name)
    @total_contacts = @contacts.count
  end

  def show
    @contact = Current.user.hubspot_contacts.find(params[:id])
  end

  private

  def authenticate
    redirect_to new_session_path unless authenticated?
  end
end