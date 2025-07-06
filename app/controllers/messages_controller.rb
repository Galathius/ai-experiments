class MessagesController < ApplicationController
  before_action :set_chat

  def create
    # Create user message
    @user_message = @chat.messages.build(message_params.merge(role: "user"))

    if @user_message.save
      # Update chat title from first message if needed
      if @chat.messages.count == 1
        @chat.generate_title_from_first_message
        @chat.save
      end

      # Generate AI response
      ai_response = generate_ai_response(@user_message.content)

      @ai_message = @chat.messages.create!(
        content: ai_response,
        role: "assistant"
      )

      # Update chat's updated_at timestamp
      @chat.touch

      render json: {
        user_message: message_json(@user_message),
        ai_message: message_json(@ai_message),
        chat_id: @chat.id
      }
    else
      render json: {
        error: "Failed to send message",
        errors: @user_message.errors.full_messages
      }, status: 422
    end
  end

  private

  def set_chat
    if params[:chat_id].present?
      @chat = Current.user.chats.find(params[:chat_id])
    else
      # Create new chat if none specified
      @chat = Current.user.chats.create!(title: "New Chat")
    end
  end

  def message_params
    params.require(:message).permit(:content)
  end

  def message_json(message)
    {
      id: message.id,
      content: message.content,
      role: message.role,
      created_at: message.created_at
    }
  end

  def generate_ai_response(user_input)
    # Use RAG to find relevant context from emails and calendar events
    relevant_context = find_relevant_context(user_input)

    # Generate AI response using OpenAI with context
    generate_openai_response(user_input, relevant_context)
  end

  def find_relevant_context(query)
    # Search across all embedded content (emails and calendar events)
    relevant_embeddings = Embedding.semantic_search(query, limit: 8)

    context_items = []

    relevant_embeddings.each do |embedding|
      case embedding.embeddable_type
      when "Email"
        email = embedding.embeddable
        context_items << {
          type: "email",
          from: email.from_name || email.from_email,
          from_email: email.from_email,
          subject: email.subject,
          date: email.received_at,
          content: email.body.to_s.truncate(300),
          relevance_score: embedding.vector ? "high" : "medium"
        }
      when "CalendarEvent"
        event = embedding.embeddable
        context_items << {
          type: "calendar_event",
          title: event.title,
          start_time: event.start_time,
          end_time: event.end_time,
          location: event.location,
          attendees: event.attendees_array,
          description: event.description.to_s.truncate(200),
          relevance_score: embedding.vector ? "high" : "medium"
        }
      when "HubspotContact"
        contact = embedding.embeddable
        context_items << {
          type: "hubspot_contact",
          name: contact.full_name,
          email: contact.email,
          company: contact.company,
          phone: contact.phone,
          relevance_score: embedding.vector ? "high" : "medium"
        }
      when "HubspotNote"
        note = embedding.embeddable
        context_items << {
          type: "hubspot_note",
          content: note.content.to_s.truncate(300),
          created_date: note.created_date,
          contact_name: note.hubspot_contact&.full_name,
          contact_email: note.hubspot_contact&.email,
          relevance_score: embedding.vector ? "high" : "medium"
        }
      end
    end

    context_items
  end

  def generate_openai_response(user_input, context_items)
    # Build system prompt with context
    system_prompt = build_system_prompt(context_items)

    client = OpenAI::Client.new(access_token: Rails.application.credentials.openai.api_key)

    begin
      # Build conversation history including previous messages
      messages = [{ role: "system", content: system_prompt }]
      
      # Add previous messages from the chat (excluding the current user message which will be added below)
      @chat.messages.order(:created_at).each do |message|
        messages << { role: message.role, content: message.content }
      end

      # Initial chat completion with tools
      response = client.chat(
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

      # Check if the AI wants to use tools
      if message["tool_calls"]
        handle_tool_calls(client, system_prompt, user_input, message)
      else
        message["content"] || "I apologize, but I couldn't generate a response at this time."
      end
    rescue => e
      Rails.logger.error "OpenAI API error: #{e.message}"
      "I'm sorry, I'm having trouble accessing my AI capabilities right now. Please try again in a moment."
    end
  end

  def handle_tool_calls(client, system_prompt, user_input, assistant_message)
    # Execute the tool calls
    tool_results = ToolExecutor.execute_tool_calls(assistant_message["tool_calls"], Current.user)

    # Build the conversation history with tool results
    messages = [{ role: "system", content: system_prompt }]
    
    # Add previous messages from the chat
    @chat.messages.order(:created_at).each do |message|
      messages << { role: message.role, content: message.content }
    end
    
    # Add the assistant's tool call response
    messages << { role: "assistant", content: assistant_message["content"], tool_calls: assistant_message["tool_calls"] }

    # Add tool results
    tool_results.each do |result|
      messages << {
        role: "tool",
        tool_call_id: result[:tool_call_id],
        content: result[:content]
      }
    end

    # Get final response from AI with tool results
    response = client.chat(
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

  def build_system_prompt(context_items)
    base_prompt = "You are an AI assistant for a financial advisor. You help with managing emails, calendar events, client relationships, HubSpot CRM data, and task management. You have access to the user's email, calendar, HubSpot contact/notes data, and task information to provide informed responses.\n\n"

    base_prompt += "You can perform actions like:\n"
    base_prompt += "- Send emails using send_email\n"
    base_prompt += "- Create calendar events using create_calendar_event\n"
    base_prompt += "- Add notes to HubSpot contacts using add_hubspot_note\n"
    base_prompt += "- Create tasks using create_task\n"
    base_prompt += "- List and filter tasks using list_tasks\n"
    base_prompt += "- Update task details using update_task\n"
    base_prompt += "- Mark tasks as completed using complete_task\n\n"

    # Add task context
    task_context = get_task_context
    if task_context.present?
      base_prompt += "CURRENT TASK STATUS:\n#{task_context}\n\n"
    end


    if context_items.any?
      base_prompt += "Here is relevant context from the user's emails, calendar, and HubSpot CRM:\n\n"

      context_items.each_with_index do |item, index|
        case item[:type]
        when "email"
          base_prompt += "EMAIL #{index + 1}:\n"
          base_prompt += "From: #{item[:from]} (#{item[:from_email]})\n"
          base_prompt += "Subject: #{item[:subject]}\n"
          base_prompt += "Date: #{item[:date].strftime('%B %d, %Y')}\n"
          base_prompt += "Content: #{item[:content]}\n\n"
        when "calendar_event"
          base_prompt += "CALENDAR EVENT #{index + 1}:\n"
          base_prompt += "Title: #{item[:title]}\n"
          base_prompt += "Date: #{item[:start_time].strftime('%B %d, %Y at %I:%M %p')}\n"
          base_prompt += "Location: #{item[:location]}\n" if item[:location].present?
          base_prompt += "Attendees: #{item[:attendees].join(', ')}\n" if item[:attendees].any?
          base_prompt += "Description: #{item[:description]}\n" if item[:description].present?
          base_prompt += "\n"
        when "hubspot_contact"
          base_prompt += "HUBSPOT CONTACT #{index + 1}:\n"
          base_prompt += "Name: #{item[:name]}\n"
          base_prompt += "Email: #{item[:email]}\n" if item[:email].present?
          base_prompt += "Company: #{item[:company]}\n" if item[:company].present?
          base_prompt += "Phone: #{item[:phone]}\n" if item[:phone].present?
          base_prompt += "Notes: #{item[:notes]}\n" if item[:notes].present?
          base_prompt += "\n"
        when "hubspot_note"
          base_prompt += "HUBSPOT NOTE #{index + 1}:\n"
          base_prompt += "Date: #{item[:created_date].strftime('%B %d, %Y')}\n" if item[:created_date]
          base_prompt += "About: #{item[:contact_name]} (#{item[:contact_email]})\n" if item[:contact_name].present?
          base_prompt += "Content: #{item[:content]}\n"
          base_prompt += "\n"
        end
      end
    else
      base_prompt += "No specific context was found for this query, but you can still provide helpful assistance based on your general knowledge.\n\n"
    end

    base_prompt += "Instructions:\n"
    base_prompt += "- Use the provided context to give accurate, specific answers\n"
    base_prompt += "- If asked about people, reference their emails or calendar events\n"
    base_prompt += "- Be helpful and professional\n"
    base_prompt += "- If you don't have enough information, say so clearly\n"
    base_prompt += "- For scheduling requests, mention you'd need calendar access to check availability\n"

    base_prompt
  end

  def get_task_context
    task_manager = TaskManager.new(Current.user)
    task_manager.get_context_for_ai
  end

end
