class ChatsController < ApplicationController
  before_action :set_chat, only: [ :show, :destroy ]

  def index
    @chats = Current.user.chats.recent
    @current_chat = @chats.first
  end

  def show
    @chats = Current.user.chats.recent
    @current_chat = @chat

    respond_to do |format|
      format.html
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


  def destroy
    @chat.destroy
    redirect_to chats_path, notice: "Chat deleted successfully"
  end

  private

  def set_chat
    @chat = Current.user.chats.find(params[:id])
  end
end
