class TasksController < ApplicationController
  before_action :authenticate

  def index
    @tasks = Current.user.tasks.order(created_at: :desc).limit(100)
    @task_manager = TaskManager.new(Current.user)
    @stats = @task_manager.get_task_summary
    @urgent_tasks = @task_manager.get_urgent_tasks
  end

  def show
    @task = Current.user.tasks.find(params[:id])
  end

  private

  def authenticate
    redirect_to new_session_path unless authenticated?
  end
end
