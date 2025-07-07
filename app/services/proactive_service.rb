class ProactiveService
  def initialize(user)
    @user = user
    @client = OpenAI::Client.new(access_token: Rails.application.credentials.openai.api_key)
  end

  def check_trigger_based_tasks(data_type, new_records)
    return if new_records.empty?

    Rails.logger.info "🔍 Checking for proactive tasks triggered by #{data_type} (#{new_records.size} new records)"

    # Use RAG to find relevant tasks
    relevant_tasks = find_relevant_tasks_with_rag(data_type, new_records)

    Rails.logger.info "Found #{relevant_tasks.size} potentially relevant tasks"

    relevant_tasks.each do |task|
      execute_proactive_task(task, new_records)
    end
  end

  private

  def find_relevant_tasks_with_rag(data_type, new_records)
    # Create a query based on the data type and new records
    query = build_search_query(data_type, new_records)

    # Search for relevant tasks using semantic search
    task_embeddings = Embedding.semantic_search(query, limit: 5)
                               .where(embeddable_type: "Task")
                               .includes(:embeddable)

    # Filter to only pending tasks belonging to the user
    relevant_tasks = task_embeddings.map(&:embeddable)
                                   .select { |task| task.user_id == @user.id && task.status == "pending" }

    Rails.logger.info "RAG search query: '#{query}' found #{relevant_tasks.size} relevant tasks"

    relevant_tasks
  end

  def build_search_query(data_type, new_records)
    # Build a semantic search query based on the trigger context
    case data_type
    when "contact"
      sample_contact = new_records.first
      "when create new contact client customer #{sample_contact.first_name if sample_contact.respond_to?(:first_name)}"
    when "email"
      "when receive new email message"
    when "calendar_event"
      "when create new meeting calendar event appointment"
    when "note"
      "when create new note comment"
    else
      "when create new #{data_type}"
    end
  end

  def execute_proactive_task(task, new_records)
    Rails.logger.info "🤖 Analyzing task for proactive execution: #{task.title}"

    # Build context about the new records
    records_context = new_records.map do |record|
      case record
      when HubspotContact
        "New HubSpot contact: #{record.first_name} #{record.last_name} (#{record.email})"
      when Email
        "New email from: #{record.from_email} with subject: #{record.subject}"
      when CalendarEvent
        "New calendar event: #{record.title} at #{record.start_time}"
      else
        "New #{record.class.name}: #{record.id}"
      end
    end.join("\n")

    prompt = build_analysis_prompt(task, records_context)

    begin
      response = @client.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: [
            { role: "system", content: "You are a task automation analyzer. If the task should execute based on new data, use available tools to perform the actions. If not, just respond why." },
            { role: "user", content: prompt }
          ],
          tools: ToolRegistry.available_tools,
          tool_choice: "auto",
          temperature: 0.3,
          max_tokens: 500
        }
      )

      message = response.dig("choices", 0, "message")
      
      if message["tool_calls"]&.any?
        Rails.logger.info "✅ Task should execute: AI called #{message['tool_calls'].size} tools"
        
        # Execute the tool calls
        tool_results = ToolExecutor.execute_tool_calls(message["tool_calls"], @user)
        successful_executions = tool_results.count { |result| result[:content].start_with?("✅") }
        
        Rails.logger.info "Executed #{successful_executions}/#{tool_results.size} proactive tools for task: #{task.title}"

        # Log the execution
        if successful_executions > 0
          @user.action_logs.create!(
            tool_name: "ProactiveTask",
            parameters: {
              task_id: task.id,
              task_title: task.title,
              trigger_type: "data_import",
              records_processed: new_records.size,
              tool_calls: message["tool_calls"]
            },
            result: {
              success: true,
              actions_executed: successful_executions,
              execution_time: Time.current
            }
          )

          Rails.logger.info "🎯 Successfully executed #{successful_executions} proactive actions for task: #{task.title}"
        end
      else
        Rails.logger.info "⏭️ Task should not execute: #{message['content']}"
      end

    rescue => e
      Rails.logger.error "Failed to analyze/execute proactive task: #{e.message}"
    end
  end

  def build_analysis_prompt(task, records_context)
    <<~PROMPT
      Task to analyze:
      Title: #{task.title}
      Description: #{task.description || 'No description'}

      New records that just arrived:
      #{records_context}

      Should this task execute based on the new records? If yes, perform the actions specified in the task description.
    PROMPT
  end
end