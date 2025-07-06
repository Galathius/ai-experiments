class ProactiveMonitoringJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Running proactive monitoring for all users..."
    
    start_time = Time.current
    user_count = 0
    notification_count = 0

    User.find_each do |user|
      user_count += 1
      initial_count = user.notifications.count
      
      ProactiveService.new(user).check_and_notify
      
      new_notifications = user.notifications.count - initial_count
      notification_count += new_notifications
      
      Rails.logger.debug "Checked user #{user.id}: #{new_notifications} new notifications"
    rescue => e
      Rails.logger.error "Error processing proactive monitoring for user #{user.id}: #{e.message}"
    end

    elapsed_time = Time.current - start_time
    Rails.logger.info "Proactive monitoring completed: #{user_count} users processed, #{notification_count} notifications created in #{elapsed_time.round(2)}s"

    # Schedule the next run in 30 minutes
    ProactiveMonitoringJob.set(wait: 30.minutes).perform_later
  end
end
