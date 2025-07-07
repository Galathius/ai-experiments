class HubspotClient
  API_BASE = 'https://api.hubapi.com'
  
  def initialize(access_token)
    @access_token = access_token
    @connection = Faraday.new(url: API_BASE) do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end
  end

  def get(path, params = {})
    response = @connection.get(path) do |req|
      req.headers['Authorization'] = "Bearer #{@access_token}"
      req.params = params
    end
    
    handle_response(response)
  end

  def post(path, body = {})
    response = @connection.post(path) do |req|
      req.headers['Authorization'] = "Bearer #{@access_token}"
      req.headers['Content-Type'] = 'application/json'
      req.body = body.to_json
    end
    
    handle_response(response)
  end

  def put(path, body = {})
    response = @connection.put(path) do |req|
      req.headers['Authorization'] = "Bearer #{@access_token}"
      req.headers['Content-Type'] = 'application/json'
      req.body = body.to_json
    end
    
    handle_response(response)
  end

  def delete(path)
    response = @connection.delete(path) do |req|
      req.headers['Authorization'] = "Bearer #{@access_token}"
    end
    
    handle_response(response)
  end

  # Contacts API
  def get_contacts(limit: 100, after: nil)
    params = { limit: limit }
    params[:after] = after if after
    get('/crm/v3/objects/contacts', params)
  end

  def create_contact(properties)
    post('/crm/v3/objects/contacts', { properties: properties })
  end

  # Notes API - HubSpot notes are engagements, not CRM objects
  def get_notes(limit: 100, after: nil, properties: [], associations: [])
    params = { 
      limit: limit,
      properties: properties.join(','),
      associations: associations.join(',')
    }
    params[:after] = after if after
    get('/crm/v3/objects/notes', params)
  end

  def create_note_with_contact(note_content, contact_id)
    # Use the original working format with associations in the request body
    payload = {
      properties: {
        hs_note_body: note_content,
        hs_timestamp: Time.current.to_i * 1000  # HubSpot expects milliseconds
      },
      associations: [
        {
          to: {
            id: contact_id
          },
          types: [
            {
              associationCategory: "HUBSPOT_DEFINED",
              associationTypeId: 202  # Note to Contact association
            }
          ]
        }
      ]
    }
    
    Rails.logger.info "Creating HubSpot note with original working format: #{payload.inspect}"
    post('/crm/v3/objects/notes', payload)
  end

  private

  def handle_response(response)
    case response.status
    when 200..299
      response.body
    when 401
      raise HubspotApiError.new("Unauthorized - token may be expired", 401, response.body)
    when 403
      error_msg = "Forbidden - insufficient permissions"
      Rails.logger.error "HubSpot 403 error details: #{response.body.inspect}"
      
      if response.body.is_a?(Hash)
        if response.body['message']
          error_msg += ": #{response.body['message']}"
        end
        if response.body['errors']
          error_msg += " | Errors: #{response.body['errors']}"
        end
      elsif response.body.is_a?(String)
        error_msg += ": #{response.body}"
      end
      
      raise HubspotApiError.new(error_msg, 403, response.body)
    when 429
      raise HubspotApiError.new("Rate limit exceeded", 429, response.body)
    else
      Rails.logger.error "HubSpot API error #{response.status}: #{response.body}"
      raise HubspotApiError.new("API Error: #{response.status}", response.status, response.body)
    end
  end
end

class HubspotApiError < StandardError
  attr_reader :code, :response_body

  def initialize(message, code = nil, response_body = nil)
    super(message)
    @code = code
    @response_body = response_body
  end
end