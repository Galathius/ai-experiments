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
    context_items = ContextBuilderService.new(user_input).build_context
    AIResponseService.new(Current.user, @chat).generate_response(user_input, context_items)
  end
end
