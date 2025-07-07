module Hubspot
  class Base
    def initialize(user)
      @user = user
      @client = build_client
    end

    private

    def build_client
      return nil unless @user.hubspot_identity&.access_token
      Hubspot::Client.new(access_token: @user.hubspot_identity.access_token)
    end

    def handle_api_error(error, operation)
      Rails.logger.error "HubSpot API error during #{operation}: #{error.code} #{error.message}"
      Rails.logger.error "Response body: #{error.response_body}" if error.respond_to?(:response_body)
      nil
    end

    def client_available?
      @client.present?
    end
  end
end