module Tools
  class BaseTool
    def self.execute(params, user)
      new(params, user).execute
    end
    
    def initialize(params, user)
      @params = params
      @user = user
    end
    
    protected
    
    attr_reader :params, :user
    
    def success_response(message, data = {})
      {
        success: true,
        message: message,
        data: data
      }
    end
    
    def error_response(error_message, details = {})
      {
        success: false,
        error: error_message,
        details: details
      }
    end
    
    def validate_required_params(*required_keys)
      missing_keys = required_keys.select { |key| params[key.to_s].blank? }
      unless missing_keys.empty?
        raise ArgumentError, "Missing required parameters: #{missing_keys.join(', ')}"
      end
    end
    
    def log_execution(result)
      Rails.logger.info "Tool executed: #{self.class.name} for user #{user.id} - #{result[:success] ? 'SUCCESS' : 'FAILED'}"
    end
  end
end