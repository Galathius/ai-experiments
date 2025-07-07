module Tools
  class CompleteTaskTool < BaseTool
    def self.openai_definition
      {
        type: "function",
        function: {
          name: tool_name,
          description: "Mark a task as completed",
          parameters: {
            type: "object",
            properties: {
              task_id: {
                type: "integer",
                description: "ID of the task to complete"
              }
            },
            required: [ "task_id" ]
          }
        }
      }
    end

    def execute
      validate_required_params(:task_id)

      begin
        task_manager = TaskManager.new(user)
        task = task_manager.complete_task(params["task_id"].to_i)

        success_response(
          "Task '#{task.title}' marked as completed",
          {
            id: task.id,
            title: task.title,
            status: task.status,
            completed_at: task.completed_at.strftime("%Y-%m-%d %H:%M")
          }
        )
      rescue ActiveRecord::RecordNotFound
        error_response("Task not found")
      rescue => e
        Rails.logger.error "CompleteTaskTool error: #{e.message}"
        error_response("Error completing task: #{e.message}")
      end
    end
  end
end
