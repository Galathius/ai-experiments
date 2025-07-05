require 'net/http'
require 'json'

class HubspotService
  API_BASE = 'https://api.hubapi.com'
  
  def initialize(access_token)
    @access_token = access_token
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
  
  private
  
  def make_request(url, method: :get, body: nil)
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
    
    http.request(request)
  end
end