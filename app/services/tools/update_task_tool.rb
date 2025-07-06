module Tools
  class UpdateTaskTool < BaseTool
    def self.openai_definition
      {
        type: "function",
        function: {
          name: tool_name,
          description: "Update an existing task's details",
          parameters: {
            type: "object",
            properties: {
              task_id: {
                type: "integer",
                description: "ID of the task to update"
              },
              title: {
                type: "string",
                description: "New title for the task (optional)"
              },
              description: {
                type: "string",
                description: "New description for the task (optional)"
              },
              status: {
                type: "string",
                enum: ["pending", "in_progress", "completed", "cancelled"],
                description: "New status for the task (optional)"
              },
              priority: {
                type: "string",
                enum: ["low", "medium", "high", "urgent"],
                description: "New priority level (optional)"
              },
              due_date: {
                type: "string",
                description: "New due date in ISO format (YYYY-MM-DD) (optional)"
              }
            },
            required: ["task_id"]
          }
        }
      }
    end

    def execute
      validate_required_params(:task_id)

      begin
        task_manager = TaskManager.new(user)
        
        # Build updates hash
        updates = {}
        updates[:title] = params["title"] if params["title"].present?
        updates[:description] = params["description"] if params["description"].present?
        updates[:status] = params["status"] if params["status"].present?
        updates[:priority] = params["priority"] if params["priority"].present?
        
        if params["due_date"].present?
          updates[:due_date] = Date.parse(params["due_date"]).beginning_of_day
        end

        # Mark as completed if status is being set to completed
        if updates[:status] == "completed"
          updates[:completed_at] = Time.current
        end

        task = task_manager.update_task(params["task_id"].to_i, updates)

        success_response(
          "Task '#{task.title}' updated successfully",
          {
            id: task.id,
            title: task.title,
            description: task.description,
            status: task.status,
            priority: task.priority,
            due_date: task.due_date&.strftime("%Y-%m-%d"),
            completed_at: task.completed_at&.strftime("%Y-%m-%d %H:%M")
          }
        )
      rescue ActiveRecord::RecordNotFound
        error_response("Task not found")
      rescue => e
        Rails.logger.error "UpdateTaskTool error: #{e.message}"
        error_response("Error updating task: #{e.message}")
      end
    end
  end
end