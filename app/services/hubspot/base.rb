module Hubspot
  class Base
    def initialize(user)
      @user = user
      @client = build_client
    end

    protected

    def with_token_refresh(&block)
      return { success: false, error: "No HubSpot connection" } unless hubspot_identity

      begin
        refresh_token_if_needed
        yield
      rescue HubspotApiError => e
        if token_expired?(e)
          Rails.logger.info "HubSpot token expired, attempting refresh for user #{@user.id}"
          if refresh_access_token
            @client = build_client
            yield
          else
            { success: false, error: "Failed to refresh HubSpot token" }
          end
        else
          raise e
        end
      end
    end

    private

    def build_client
      return nil unless hubspot_identity&.access_token
      HubspotClient.new(hubspot_identity.access_token)
    end

    def hubspot_identity
      @hubspot_identity ||= @user.hubspot_identity
    end

    def handle_api_error(error, operation)
      Rails.logger.error "HubSpot API error during #{operation}: #{error.code} #{error.message}"
      Rails.logger.error "Response body: #{error.response_body}" if error.respond_to?(:response_body)
      nil
    end

    def client_available?
      @client.present?
    end

    def token_expired?(error)
      error.is_a?(HubspotApiError) && 
      (error.code == 401 || error.response_body&.include?("expired"))
    end

    def token_needs_refresh?
      return false unless hubspot_identity&.expires_at
      
      # Refresh if token expires within 5 minutes
      hubspot_identity.expires_at <= 5.minutes.from_now
    end

    def refresh_token_if_needed
      refresh_access_token if token_needs_refresh?
    end

    def refresh_access_token
      return false unless hubspot_identity&.refresh_token

      begin
        conn = Faraday.new(url: 'https://api.hubapi.com') do |f|
          f.request :url_encoded
          f.adapter Faraday.default_adapter
        end

        response = conn.post('/oauth/v1/token') do |req|
          req.body = {
            grant_type: 'refresh_token',
            client_id: Rails.application.credentials.oauth.hubspot.client_id,
            client_secret: Rails.application.credentials.oauth.hubspot.client_secret,
            refresh_token: hubspot_identity.refresh_token
          }
        end

        if response.success?
          token_data = JSON.parse(response.body)
          
          hubspot_identity.update!(
            access_token: token_data['access_token'],
            refresh_token: token_data['refresh_token'] || hubspot_identity.refresh_token,
            expires_at: Time.current + token_data['expires_in'].seconds
          )

          Rails.logger.info "Successfully refreshed HubSpot token for user #{@user.id}"
          true
        else
          Rails.logger.error "Failed to refresh HubSpot token: #{response.status} #{response.body}"
          false
        end
      rescue => e
        Rails.logger.error "Error refreshing HubSpot token for user #{@user.id}: #{e.message}"
        false
      end
    end
  end
end
