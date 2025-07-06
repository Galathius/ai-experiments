require 'net/http'
require 'json'

class HubspotService
  API_BASE = 'https://api.hubapi.com'
  
  def initialize(access_token, hubspot_identity = nil)
    @access_token = access_token
    @hubspot_identity = hubspot_identity
  end
  
  def get_contacts(limit: 100, after: nil)
    url = URI("#{API_BASE}/crm/v3/objects/contacts")
    params = { limit: limit }
    params[:after] = after if after
    url.query = URI.encode_www_form(params)
    
    response = make_request(url)
    
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      Rails.logger.error "HubSpot API error: #{response.code} #{response.message}"
      nil
    end
  end
  
  def get_contact(contact_id)
    url = URI("#{API_BASE}/crm/v3/objects/contacts/#{contact_id}")
    
    response = make_request(url)
    
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      Rails.logger.error "HubSpot API error: #{response.code} #{response.message}"
      nil
    end
  end
  
  def create_contact(properties)
    url = URI("#{API_BASE}/crm/v3/objects/contacts")
    
    body = {
      properties: properties
    }.to_json
    
    response = make_request(url, method: :post, body: body)
    
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      Rails.logger.error "HubSpot API error: #{response.code} #{response.message}"
      nil
    end
  end
  
  def get_notes(limit: 100, after: nil)
    url = URI("#{API_BASE}/crm/v3/objects/notes")
    params = { 
      limit: limit,
      properties: 'hs_note_body,hs_timestamp,hs_createdate,hs_lastmodifieddate',
      associations: 'contacts'
    }
    params[:after] = after if after
    url.query = URI.encode_www_form(params)
    
    response = make_request(url)
    
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      Rails.logger.error "HubSpot API error: #{response.code} #{response.message}"
      nil
    end
  end
  
  def get_contact_notes(contact_id, limit: 100)
    url = URI("#{API_BASE}/crm/v3/objects/contacts/#{contact_id}/associations/notes")
    params = { limit: limit }
    url.query = URI.encode_www_form(params)
    
    response = make_request(url)
    
    if response.is_a?(Net::HTTPSuccess)
      associations_data = JSON.parse(response.body)
      note_ids = associations_data['results']&.map { |result| result['id'] } || []
      
      # Fetch actual note content for each note ID
      notes = []
      note_ids.each do |note_id|
        note_data = get_note(note_id)
        notes << note_data if note_data
      end
      
      notes
    else
      Rails.logger.error "HubSpot API error fetching contact notes: #{response.code} #{response.message}"
      []
    end
  end
  
  def get_note(note_id)
    url = URI("#{API_BASE}/crm/v3/objects/notes/#{note_id}")
    # Request specific properties for notes
    params = { properties: 'hs_note_body,hs_timestamp,hs_createdate' }
    url.query = URI.encode_www_form(params)
    
    response = make_request(url)
    
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      Rails.logger.error "HubSpot API error fetching note: #{response.code} #{response.message}"
      nil
    end
  end
  
  private
  
  def make_request(url, method: :get, body: nil, retry_count: 0)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    
    request = case method
              when :get
                Net::HTTP::Get.new(url)
              when :post
                Net::HTTP::Post.new(url)
              when :put
                Net::HTTP::Put.new(url)
              when :delete
                Net::HTTP::Delete.new(url)
              end
    
    request['Authorization'] = "Bearer #{@access_token}"
    request['Content-Type'] = 'application/json' if body
    request.body = body if body
    
    response = http.request(request)
    
    # Handle 401 Unauthorized - try to refresh token once
    if response.code == '401' && retry_count == 0 && @hubspot_identity&.refresh_token
      Rails.logger.info "HubSpot token expired, attempting refresh..."
      if refresh_access_token
        return make_request(url, method: method, body: body, retry_count: 1)
      end
    end
    
    response
  end
  
  def refresh_access_token
    return false unless @hubspot_identity&.refresh_token
    
    url = URI('https://api.hubapi.com/oauth/v1/token')
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(url)
    request['Content-Type'] = 'application/x-www-form-urlencoded'
    request.body = URI.encode_www_form({
      grant_type: 'refresh_token',
      client_id: Rails.application.credentials.dig(:oauth, :hubspot, :client_id),
      client_secret: Rails.application.credentials.dig(:oauth, :hubspot, :client_secret),
      refresh_token: @hubspot_identity.refresh_token
    })
    
    response = http.request(request)
    
    if response.is_a?(Net::HTTPSuccess)
      token_data = JSON.parse(response.body)
      @access_token = token_data['access_token']
      
      # Update the stored token
      @hubspot_identity.update!(
        access_token: token_data['access_token'],
        refresh_token: token_data['refresh_token'] || @hubspot_identity.refresh_token
      )
      
      Rails.logger.info "HubSpot token refreshed successfully"
      true
    else
      Rails.logger.error "Failed to refresh HubSpot token: #{response.code} #{response.message}"
      false
    end
  rescue => e
    Rails.logger.error "Error refreshing HubSpot token: #{e.message}"
    false
  end
end