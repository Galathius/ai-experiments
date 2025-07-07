class AIResponseService
  def initialize(user, chat)
    @user = user
    @chat = chat
    @client = OpenAI::Client.new(access_token: Rails.application.credentials.openai.api_key)
  end

  def generate_response(user_input, context_items)
    system_prompt = SystemPromptService.new(context_items, @user).build_prompt

    begin
      messages = build_conversation_history(system_prompt)

      response = @client.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: messages,
          tools: ToolRegistry.available_tools,
          tool_choice: "auto",
          temperature: 0.7,
          max_tokens: 1000
        }
      )

      message = response.dig("choices", 0, "message")

      if message["tool_calls"]
        handle_tool_calls(system_prompt, user_input, message)
      else
        message["content"] || "I apologize, but I couldn't generate a response at this time."
      end
    rescue => e
      Rails.logger.error "OpenAI API error: #{e.message}"
      "I'm sorry, I'm having trouble accessing my AI capabilities right now. Please try again in a moment."
    end
  end

  private

  def build_conversation_history(system_prompt)
    messages = [ { role: "system", content: system_prompt } ]

    @chat.messages.order(:created_at).each do |message|
      messages << { role: message.role, content: message.content }
    end

    messages
  end

  def handle_tool_calls(system_prompt, user_input, assistant_message)
    tool_results = ToolExecutor.execute_tool_calls(assistant_message["tool_calls"], @user)

    messages = build_conversation_history(system_prompt)
    messages << { role: "assistant", content: assistant_message["content"], tool_calls: assistant_message["tool_calls"] }

    tool_results.each do |result|
      messages << {
        role: "tool",
        tool_call_id: result[:tool_call_id],
        content: result[:content]
      }
    end

    response = @client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: messages,
        temperature: 0.7,
        max_tokens: 1000
      }
    )

    response.dig("choices", 0, "message", "content") || "I completed the requested actions."
  rescue => e
    Rails.logger.error "Tool calling error: #{e.message}"
    "I attempted to perform the requested actions but encountered an error. Please check your connections and try again."
  end
end
