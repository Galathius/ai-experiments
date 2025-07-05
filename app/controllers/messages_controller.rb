class MessagesController < ApplicationController
  before_action :set_chat
  
  def create
    # Create user message
    @user_message = @chat.messages.build(message_params.merge(role: 'user'))
    
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
        role: 'assistant'
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
      when 'Email'
        email = embedding.embeddable
        context_items << {
          type: 'email',
          from: email.from_name || email.from_email,
          from_email: email.from_email,
          subject: email.subject,
          date: email.received_at,
          content: email.body.to_s.truncate(300),
          relevance_score: embedding.vector ? 'high' : 'medium'
        }
      when 'CalendarEvent'
        event = embedding.embeddable
        context_items << {
          type: 'calendar_event',
          title: event.title,
          start_time: event.start_time,
          end_time: event.end_time,
          location: event.location,
          attendees: event.attendees_array,
          description: event.description.to_s.truncate(200),
          relevance_score: embedding.vector ? 'high' : 'medium'
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
      response = client.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: user_input }
          ],
          temperature: 0.7,
          max_tokens: 1000
        }
      )
      
      response.dig("choices", 0, "message", "content") || "I apologize, but I couldn't generate a response at this time."
    rescue => e
      Rails.logger.error "OpenAI API error: #{e.message}"
      "I'm sorry, I'm having trouble accessing my AI capabilities right now. Please try again in a moment."
    end
  end
  
  def build_system_prompt(context_items)
    base_prompt = "You are an AI assistant for a financial advisor. You help with managing emails, calendar events, and client relationships. You have access to the user's email and calendar data to provide informed responses.\n\n"
    
    if context_items.any?
      base_prompt += "Here is relevant context from the user's emails and calendar:\n\n"
      
      context_items.each_with_index do |item, index|
        case item[:type]
        when 'email'
          base_prompt += "EMAIL #{index + 1}:\n"
          base_prompt += "From: #{item[:from]} (#{item[:from_email]})\n"
          base_prompt += "Subject: #{item[:subject]}\n"
          base_prompt += "Date: #{item[:date].strftime('%B %d, %Y')}\n"
          base_prompt += "Content: #{item[:content]}\n\n"
        when 'calendar_event'
          base_prompt += "CALENDAR EVENT #{index + 1}:\n"
          base_prompt += "Title: #{item[:title]}\n"
          base_prompt += "Date: #{item[:start_time].strftime('%B %d, %Y at %I:%M %p')}\n"
          base_prompt += "Location: #{item[:location]}\n" if item[:location].present?
          base_prompt += "Attendees: #{item[:attendees].join(', ')}\n" if item[:attendees].any?
          base_prompt += "Description: #{item[:description]}\n" if item[:description].present?
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
end
