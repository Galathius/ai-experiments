class ChatsController < ApplicationController
  before_action :set_chat, only: [ :show ]

  def interface
    @chats = Current.user.chats.recent
    @current_chat = @chats.first
    render layout: false
  end

  def show
    respond_to do |format|
      format.json do
        render json: {
          chat: {
            id: @chat.id,
            title: @chat.title
          },
          messages: @chat.messages.ordered.map do |message|
            {
              id: message.id,
              content: message.content,
              role: message.role,
              created_at: message.created_at
            }
          end
        }
      end
    end
  end

  private

  def set_chat
    @chat = Current.user.chats.find(params[:id])
  end
end
