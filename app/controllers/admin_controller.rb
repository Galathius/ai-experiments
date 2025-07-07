class AdminController < ApplicationController
  before_action :ensure_authenticated

  def reset_all_data
    if Rails.env.production?
      # Extra safety check in production
      unless params[:confirm] == "YES_DELETE_EVERYTHING_FOR_ALL_USERS"
        return redirect_to root_path, alert: "Reset cancelled. Confirmation required."
      end
    end

    begin
      # Keep track of what we're deleting
      deleted_counts = {}

      # Delete ALL data for ALL users in dependency order
      deleted_counts[:action_logs] = ActionLog.count
      ActionLog.delete_all

      deleted_counts[:tasks] = Task.count
      Task.delete_all

      deleted_counts[:embeddings] = Embedding.count
      Embedding.delete_all

      deleted_counts[:messages] = Message.count
      Message.delete_all

      deleted_counts[:chats] = Chat.count
      Chat.delete_all

      deleted_counts[:hubspot_notes] = HubspotNote.count
      HubspotNote.delete_all

      deleted_counts[:hubspot_contacts] = HubspotContact.count
      HubspotContact.delete_all

      deleted_counts[:calendar_events] = CalendarEvent.count
      CalendarEvent.delete_all

      deleted_counts[:emails] = Email.count
      Email.delete_all

      # Also delete sessions and oauth identities for complete reset
      deleted_counts[:sessions] = Session.count
      Session.delete_all

      deleted_counts[:oauth_identities] = OmniAuthIdentity.count
      OmniAuthIdentity.delete_all

      deleted_counts[:users] = User.count
      User.delete_all

      # Clear any pgvector status
      if ActiveRecord::Base.connection.table_exists?("pgvector_status")
        deleted_counts[:pgvector_status] = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM pgvector_status").first["count"]
        ActiveRecord::Base.connection.execute("DELETE FROM pgvector_status")
      end

      total_deleted = deleted_counts.values.sum
      summary = deleted_counts.map { |table, count| "#{count} #{table}" }.join(", ")

      # After deleting everything, user will need to log in again
      redirect_to new_session_path, notice: "🔥 NUCLEAR RESET COMPLETE: Deleted #{summary} (#{total_deleted} total records). Please log in again."
    rescue => e
      Rails.logger.error "Error during nuclear reset: #{e.message}\n#{e.backtrace.join("\n")}"
      redirect_to root_path, alert: "Error during nuclear reset: #{e.message}"
    end
  end

  private

  def ensure_authenticated
    redirect_to root_path, alert: "Access denied" unless Current.user
  end
end
