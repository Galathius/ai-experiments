class ToolExecutor
  TOOLS = {
    "send_email" => Tools::SendEmailTool,
    "create_calendar_event" => Tools::CreateCalendarEventTool,
    "add_hubspot_note" => Tools::AddHubspotNoteTool
  }.freeze

  def self.execute_tool_calls(tool_calls, user)
    new(user).execute_tool_calls(tool_calls)
  end

  def initialize(user)
    @user = user
  end

  def execute_tool_calls(tool_calls)
    results = []
    
    tool_calls.each do |tool_call|
      result = execute_single_tool_call(tool_call)
      results << result
    end
    
    results
  end

  private

  attr_reader :user

  def execute_single_tool_call(tool_call)
    function_name = tool_call["function"]["name"]
    arguments = parse_arguments(tool_call["function"]["arguments"])
    tool_call_id = tool_call["id"]
    
    Rails.logger.info "Executing tool: #{function_name} for user #{user.id}"
    
    if TOOLS[function_name]
      begin
        # Check permissions before executing
        unless can_execute_tool?(function_name)
          result = permission_denied_result(function_name)
        else
          # Execute the tool
          result = TOOLS[function_name].execute(arguments, user)
        end
        
        # Log the action
        log_action(function_name, arguments, result)
        
        {
          tool_call_id: tool_call_id,
          content: format_tool_result(function_name, result)
        }
      rescue => e
        Rails.logger.error "Tool execution error for #{function_name}: #{e.message}"
        error_result = {
          success: false,
          error: "Tool execution failed: #{e.message}"
        }
        
        log_action(function_name, arguments, error_result)
        
        {
          tool_call_id: tool_call_id,
          content: format_tool_result(function_name, error_result)
        }
      end
    else
      {
        tool_call_id: tool_call_id,
        content: "Error: Unknown tool '#{function_name}'"
      }
    end
  end

  def parse_arguments(arguments_string)
    JSON.parse(arguments_string)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse tool arguments: #{e.message}"
    {}
  end

  def can_execute_tool?(tool_name)
    case tool_name
    when "send_email", "create_calendar_event"
      user.google_identity&.access_token.present?
    when "add_hubspot_note"
      user.hubspot_identity&.access_token.present?
    else
      false
    end
  end

  def permission_denied_result(tool_name)
    connection_type = case tool_name
                     when "send_email", "create_calendar_event"
                       "Google"
                     when "add_hubspot_note"
                       "HubSpot"
                     else
                       "required service"
                     end
    
    {
      success: false,
      error: "Permission denied: #{connection_type} connection required for #{tool_name}"
    }
  end

  def log_action(tool_name, parameters, result)
    user.action_logs.create!(
      tool_name: tool_name,
      parameters: parameters,
      result: result
    )
  rescue => e
    Rails.logger.error "Failed to log action: #{e.message}"
  end

  def format_tool_result(tool_name, result)
    if result[:success]
      "✅ #{result[:message]}"
    else
      "❌ #{result[:error]}"
    end
  end
end