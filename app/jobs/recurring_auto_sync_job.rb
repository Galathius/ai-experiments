class RecurringAutoSyncJob < ApplicationJob
  queue_as :default
  
  def perform
    Rails.logger.info "Starting recurring auto-sync for all connected users"
    
    # Find all users with connected Google or HubSpot accounts
    connected_users = User.joins(:omniauth_identities)
                         .where(omniauth_identities: { provider: ['google_oauth2', 'hubspot'] })
                         .distinct
    
    sync_count = 0
    error_count = 0
    
    connected_users.find_each do |user|
      begin
        # Only sync if user has been active recently (logged in within last 7 days)
        if user_recently_active?(user)
          AutoSyncJob.perform_later(user.id)
          sync_count += 1
        end
      rescue => e
        Rails.logger.error "Failed to queue auto-sync for user #{user.id}: #{e.message}"
        error_count += 1
      end
    end
    
    Rails.logger.info "Recurring auto-sync completed: queued #{sync_count} jobs, #{error_count} errors"
    
    # Schedule the next run (30 minutes from now)
    RecurringAutoSyncJob.set(wait: 30.minutes).perform_later
  end
  
  private
  
  def user_recently_active?(user)
    # Consider user active if they have sessions or chats in the last 7 days
    recent_threshold = 7.days.ago
    
    user.sessions.where('created_at > ?', recent_threshold).exists? ||
    user.chats.where('updated_at > ?', recent_threshold).exists?
  end
end