module Tools
  class ListTasksTool < BaseTool
    def self.openai_definition
      {
        type: "function",
        function: {
          name: tool_name,
          description: "List and retrieve user's tasks with optional filtering",
          parameters: {
            type: "object",
            properties: {
              status: {
                type: "string",
                enum: [ "pending", "in_progress", "completed", "cancelled" ],
                description: "Filter by task status (optional)"
              },
              priority: {
                type: "string",
                enum: [ "low", "medium", "high", "urgent" ],
                description: "Filter by priority level (optional)"
              },
              filter: {
                type: "string",
                enum: [ "overdue", "due_soon", "active" ],
                description: "Special filters: overdue, due_soon, or active tasks (optional)"
              },
              limit: {
                type: "integer",
                description: "Maximum number of tasks to return (default: 10)"
              }
            }
          }
        }
      }
    end

    def execute
      begin
        task_manager = TaskManager.new(user)

        # Build filters
        filters = {}
        filters[:status] = params["status"] if params["status"].present?
        filters[:priority] = params["priority"] if params["priority"].present?

        case params["filter"]
        when "overdue"
          filters[:overdue] = true
        when "due_soon"
          filters[:due_soon] = true
        when "active"
          filters[:active] = true
        end

        tasks = task_manager.list_tasks(filters)
        limit = params["limit"]&.to_i || 10
        tasks = tasks.limit(limit)

        summary = task_manager.get_task_summary

        task_list = tasks.map do |task|
          {
            id: task.id,
            title: task.title,
            description: task.description,
            status: task.status,
            priority: task.priority,
            due_date: task.due_date&.strftime("%Y-%m-%d %H:%M"),
            overdue: task.overdue?,
            created_at: task.created_at.strftime("%Y-%m-%d")
          }
        end

        success_response(
          "Found #{tasks.count} task(s)",
          {
            tasks: task_list,
            summary: summary,
            filters_applied: filters
          }
        )
      rescue => e
        Rails.logger.error "ListTasksTool error: #{e.message}"
        error_response("Error listing tasks: #{e.message}")
      end
    end
  end
end
