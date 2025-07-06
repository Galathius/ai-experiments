class NotificationsController < ApplicationController
  before_action :authenticate

  def index
    @notifications = Current.user.notifications.recent.limit(50)
    @unread_count = Current.user.notifications.unread.count
    @stats = {
      total: Current.user.notifications.count,
      unread: @unread_count,
      task_reminders: Current.user.notifications.by_type('task_reminder').count,
      overdue_alerts: Current.user.notifications.by_type('task_overdue').count,
      calendar_reminders: Current.user.notifications.by_type('calendar_reminder').count,
      suggestions: Current.user.notifications.by_type('proactive_suggestion').count
    }
  end

  def show
    @notification = Current.user.notifications.find(params[:id])
    @notification.mark_as_read! unless @notification.read?
  end

  def update
    @notification = Current.user.notifications.find(params[:id])
    
    if params[:mark_as_read]
      @notification.mark_as_read!
      render json: { status: 'read' }
    elsif params[:mark_as_unread]
      @notification.mark_as_unread!
      render json: { status: 'unread' }
    else
      render json: { error: 'Invalid action' }, status: 422
    end
  end

  private

  def authenticate
    redirect_to new_session_path unless authenticated?
  end
end
