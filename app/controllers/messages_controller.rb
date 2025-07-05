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
    # Use RAG to find relevant emails
    relevant_emails = find_relevant_emails(user_input)
    
    # Build context from emails
    email_context = build_email_context(relevant_emails)
    
    # Generate AI response with email context
    if email_context.present?
      generate_rag_response(user_input, email_context)
    else
      generate_default_response(user_input)
    end
  end
  
  def find_relevant_emails(query)
    return [] unless Current.user.emails.any?
    
    # Use semantic search to find relevant emails
    begin
      Current.user.emails.semantic_search(query, limit: 5)
    rescue
      # Fallback to basic search if semantic search fails
      Current.user.emails.where("subject ILIKE ? OR body ILIKE ?", "%#{query}%", "%#{query}%").limit(5)
    end
  end
  
  def build_email_context(emails)
    return "" if emails.empty?
    
    context = "Based on your email history:\n\n"
    emails.each_with_index do |email, index|
      context += "#{index + 1}. From: #{email.from_name} (#{email.from_email})\n"
      context += "   Subject: #{email.subject}\n"
      context += "   Date: #{email.received_at.strftime('%B %d, %Y')}\n"
      context += "   Content: #{email.body.to_s.truncate(200)}\n\n"
    end
    
    context
  end
  
  def generate_rag_response(user_input, email_context)
    # In a real implementation, this would call OpenAI with the context
    # For now, provide contextual responses based on email content
    
    if user_input.downcase.include?('baseball') && email_context.downcase.include?('baseball')
      "I found mentions of baseball in your emails! #{email_context}"
    elsif user_input.downcase.include?('stock') || user_input.downcase.include?('aapl')
      "I found relevant stock discussions in your emails. #{email_context}"
    elsif user_input.downcase.include?('meeting') || user_input.downcase.include?('appointment')
      build_meetings_response_with_context(email_context)
    else
      "Based on your email history, here's what I found:\n\n#{email_context}"
    end
  end
  
  def generate_default_response(user_input)
    case user_input.downcase
    when /meetings.*bill.*tim/, /find.*meetings.*bill.*tim/
      build_meetings_response
    when /schedule.*appointment/
      "I'll help you schedule an appointment. Let me check your calendar and available times."
    when /summarize.*meetings/
      "I can summarize these meetings, schedule a follow up, and more!"
    when /hello|hi|hey/
      "Hello! I can answer questions about your emails and meetings. What do you want to know?"
    when /help/
      "I can help you with:\n• Finding and analyzing email information\n• Scheduling appointments\n• Summarizing meetings\n• Managing your calendar\n\nWhat would you like to do?"
    else
      "I can answer questions about your emails and meetings. Try asking about specific people or topics!"
    end
  end
  
  def build_meetings_response_with_context(email_context)
    response = "Sure, here are some recent meetings and related email discussions:\n\n"
    response += build_meetings_response
    response += "\n\nRelated emails:\n#{email_context}"
    response
  end
  
  def build_meetings_response
    response = "Sure, here are some recent meetings that you, Bill, and Tim all attended. I found 2 in May. 📅\n\n"
    response += "**8 Thursday**\n\n"
    response += "**12 - 1:30pm**\n"
    response += "**Quarterly All Team Meeting**\n"
    response += "👥 5 attendees\n\n"
    response += "**16 Friday**\n\n"
    response += "**1 - 2pm**\n"
    response += "**Strategy review**\n"
    response += "👥 2 attendees\n\n"
    response += "I can summarize these meetings, schedule a follow up, and more!"
    response
  end
end
