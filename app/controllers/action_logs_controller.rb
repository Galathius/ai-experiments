class ActionLogsController < ApplicationController
  before_action :authenticate

  def index
    @action_logs = Current.user.action_logs.recent.limit(50)
    @stats = {
      total: Current.user.action_logs.count,
      successful: Current.user.action_logs.successful.count,
      failed: Current.user.action_logs.failed.count,
      today: Current.user.action_logs.where(created_at: Date.current.all_day).count
    }
  end

  private

  def authenticate
    redirect_to new_session_path unless authenticated?
  end
end
