module Tools
  class CreateTaskTool < BaseTool
    def self.openai_definition
      {
        type: "function",
        function: {
          name: tool_name,
          description: "Create a new task for the user to track and remember",
          parameters: {
            type: "object",
            properties: {
              title: {
                type: "string",
                description: "Title of the task"
              },
              description: {
                type: "string",
                description: "Detailed description of the task (optional)"
              },
              priority: {
                type: "string",
                enum: ["low", "medium", "high", "urgent"],
                description: "Priority level of the task"
              },
              due_date: {
                type: "string",
                description: "Due date in ISO format (YYYY-MM-DD) (optional)"
              }
            },
            required: ["title"]
          }
        }
      }
    end

    def execute
      validate_required_params(:title)

      begin
        task_manager = TaskManager.new(user)
        
        # Parse due_date if provided
        due_date = nil
        if params["due_date"].present?
          due_date = Date.parse(params["due_date"]).beginning_of_day
        end

        task = task_manager.create_task(
          title: params["title"],
          description: params["description"],
          priority: params["priority"] || "medium",
          due_date: due_date,
          metadata: {
            created_by: "ai_assistant",
            created_from: "chat"
          }
        )

        success_response(
          "Task '#{task.title}' created successfully",
          {
            id: task.id,
            title: task.title,
            priority: task.priority,
            due_date: task.due_date&.strftime("%Y-%m-%d"),
            status: task.status
          }
        )
      rescue => e
        Rails.logger.error "CreateTaskTool error: #{e.message}"
        error_response("Error creating task: #{e.message}")
      end
    end
  end
end