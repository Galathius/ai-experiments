class AutoSyncJob < ApplicationJob
  queue_as :default

  def perform(user_id, force: false)
    user = User.find(user_id)

    Rails.logger.info "Starting auto-sync for user #{user.id} (force: #{force})"

    results = AutoSyncService.sync_user_data(user, force: force)

    Rails.logger.info "Auto-sync completed for user #{user.id}: #{results}"

    # Create a notification if there were significant updates
    notify_user_of_sync_results(user, results) if sync_had_updates?(results)

  rescue => e
    Rails.logger.error "Auto-sync failed for user #{user_id}: #{e.message}"

    # Create error notification for user
    user = User.find_by(id: user_id)
    if user
      user.notifications.create!(
        notification_type: "system_alert",
        title: "Data Sync Error",
        message: "Failed to sync your data: #{e.message}"
      )
    end

    raise e
  end

  private

  def sync_had_updates?(results)
    results.values.any? do |provider_results|
      next false unless provider_results.is_a?(Hash)

      provider_results.values.any? do |sync_result|
        next false unless sync_result.is_a?(Hash) && sync_result[:success]

        (sync_result[:imported] || 0) > 0
      end
    end
  end

  def notify_user_of_sync_results(user, results)
    total_imported = 0
    sync_details = []

    results.each do |provider, provider_results|
      next unless provider_results.is_a?(Hash)

      provider_results.each do |data_type, sync_result|
        next unless sync_result.is_a?(Hash) && sync_result[:success] && sync_result[:imported] > 0

        total_imported += sync_result[:imported]
        sync_details << "#{sync_result[:imported]} #{data_type} from #{provider.to_s.capitalize}"
      end
    end

    return if total_imported == 0

    user.notifications.create!(
      notification_type: "proactive_suggestion",
      title: "New Data Synced",
      message: "Imported #{sync_details.join(', ')}. Your AI assistant now has access to the latest information."
    )
  end
end
