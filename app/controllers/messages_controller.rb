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
    # Mock AI responses based on the mockup design
    case user_input.downcase
    when /meetings.*bill.*tim/, /find.*meetings.*bill.*tim/
      build_meetings_response
    when /schedule.*appointment/
      "I'll help you schedule an appointment. Let me check your calendar and available times."
    when /summarize.*meetings/
      "I can summarize these meetings, schedule a follow up, and more!"
    when /hello|hi|hey/
      "Hello! I can answer questions about any Jump meeting. What do you want to know?"
    when /help/
      "I can help you with:\n• Finding and analyzing meeting information\n• Scheduling appointments\n• Summarizing meetings\n• Managing your calendar\n\nWhat would you like to do?"
    else
      "I can answer questions about any Jump meeting. What do you want to know?"
    end
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
