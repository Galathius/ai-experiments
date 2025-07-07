class ChatsController < ApplicationController
  before_action :set_chat, only: [ :show, :destroy ]

  def index
    @chats = Current.user.chats.recent
    @current_chat = @chats.first
  end

  def interface
    @chats = Current.user.chats.recent
    @current_chat = @chats.first
    render layout: false
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

  def pull_data
    # Trigger sync for all connected services
    if Current.user.google_identity || Current.user.hubspot_identity
      # Track what existed before sync
      before_counts = {
        emails: Current.user.emails.count,
        calendar_events: Current.user.calendar_events.count,
        hubspot_contacts: Current.user.hubspot_contacts.count,
        hubspot_notes: Current.user.hubspot_notes.count
      }
      
      # Start background import jobs
      jobs_started = []
      
      if Current.user.google_identity
        ImportEmailsJob.perform_later(Current.user.id)
        ImportCalendarEventsJob.perform_later(Current.user.id)
        jobs_started << "Google emails & calendar"
      end
      
      if Current.user.hubspot_identity
        ImportHubspotContactsJob.perform_later(Current.user.id) if defined?(ImportHubspotContactsJob)
        ImportHubspotNotesJob.perform_later(Current.user.id) if defined?(ImportHubspotNotesJob)
        jobs_started << "HubSpot contacts & notes"
      end
      
      # Schedule proactive task checking after imports complete
      CheckTriggeredTasksJob.set(wait: 30.seconds).perform_later(Current.user.id, before_counts)
      
      respond_to do |format|
        format.html { redirect_to chats_path, notice: "Data sync started for: #{jobs_started.join(', ')}. This may take a few minutes." }
        format.json { render json: { status: 'success', message: "Syncing: #{jobs_started.join(', ')}" } }
      end
    else
      respond_to do |format|
        format.html { redirect_to chats_path, alert: "No connected accounts to sync data from." }
        format.json { render json: { status: 'error', message: "No connected accounts" } }
      end
    end
  end

  private

  def set_chat
    @chat = Current.user.chats.find(params[:id])
  end
end
