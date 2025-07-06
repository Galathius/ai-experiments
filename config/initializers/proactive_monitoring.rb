# Start proactive monitoring after Rails has fully loaded
Rails.application.configure do
  config.after_initialize do
    # Only start in production or when explicitly enabled
    if Rails.env.production? || ENV['ENABLE_PROACTIVE_MONITORING'] == 'true'
      # Wait a bit for the app to fully start, then begin monitoring
      ProactiveMonitoringJob.set(wait: 1.minute).perform_later
      Rails.logger.info "Proactive monitoring scheduled to start in 1 minute"
    else
      Rails.logger.info "Proactive monitoring disabled (set ENABLE_PROACTIVE_MONITORING=true to enable)"
    end
  end
end