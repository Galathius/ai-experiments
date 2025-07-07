class ProactiveService
  def initialize(user)
    @user = user
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

    # Use AI to analyze if this task should trigger and what actions to take
    analysis = analyze_task_with_ai(task, new_records)

    return unless analysis[:should_execute]

    Rails.logger.info "✅ Task should execute: #{analysis[:reasoning]}"

    # Execute the determined actions
    actions_executed = 0

    new_records.each do |record|
      if execute_actions_for_record(task, record, analysis[:actions])
        actions_executed += 1
      end
    end

    # Log the execution
    if actions_executed > 0
      @user.action_logs.create!(
        tool_name: "ProactiveTask",
        parameters: {
          task_id: task.id,
          task_title: task.title,
          trigger_type: "data_import",
          records_processed: new_records.size,
          analysis: analysis
        },
        result: {
          success: true,
          actions_executed: actions_executed,
          execution_time: Time.current
        }
      )

      Rails.logger.info "🎯 Successfully executed #{actions_executed} proactive actions for task: #{task.title}"
    end
  end

  def analyze_task_with_ai(task, new_records)
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
      client = OpenAI::Client.new(access_token: Rails.application.credentials.openai.api_key)

      response = client.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: [
            { role: "system", content: "You are a task automation analyzer. Analyze whether a task should trigger and what actions to take." },
            { role: "user", content: prompt }
          ],
          temperature: 0.3,
          max_tokens: 500
        }
      )

      result = response.dig("choices", 0, "message", "content")
      parse_ai_analysis(result)

    rescue => e
      Rails.logger.error "Failed to analyze task with AI: #{e.message}"
      { should_execute: false, reasoning: "AI analysis failed", actions: [] }
    end
  end

  def build_analysis_prompt(task, records_context)
    <<~PROMPT
      Task to analyze:
      Title: #{task.title}
      Description: #{task.description || 'No description'}

      New records that just arrived:
      #{records_context}

      Please analyze:
      1. Should this task trigger based on the new records? (yes/no)
      2. What's the reasoning?
      3. What actions should be executed?

      Respond in this JSON format:
      {
        "should_execute": true/false,
        "reasoning": "brief explanation",
        "actions": [
          {
            "type": "send_email",
            "recipient": "email@example.com",
            "subject": "email subject",
            "content": "email content"
          },
          {
            "type": "create_task",#{' '}
            "title": "task title",
            "description": "task description"
          },
          {
            "type": "create_calendar_event",
            "title": "event title",#{' '}
            "description": "event description"
          }
        ]
      }

      Only include actions that are clearly specified in the task description.
    PROMPT
  end

  def parse_ai_analysis(ai_response)
    begin
      # Try to extract JSON from the response
      json_match = ai_response.match(/\{.*\}/m)
      if json_match
        result = JSON.parse(json_match[0])
        {
          should_execute: result["should_execute"] || false,
          reasoning: result["reasoning"] || "No reasoning provided",
          actions: result["actions"] || []
        }
      else
        { should_execute: false, reasoning: "Could not parse AI response", actions: [] }
      end
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse AI analysis JSON: #{e.message}"
      { should_execute: false, reasoning: "JSON parse error", actions: [] }
    end
  end

  def execute_actions_for_record(task, record, actions)
    actions_executed = false

    actions.each do |action|
      case action["type"]
      when "send_email"
        if execute_send_email_action(action, record)
          actions_executed = true
        end
      when "create_task"
        if execute_create_task_action(action, record)
          actions_executed = true
        end
      when "create_calendar_event"
        if execute_create_calendar_event_action(action, record)
          actions_executed = true
        end
      end
    end

    actions_executed
  end

  def execute_send_email_action(action, record)
    # Get recipient email from action or record
    recipient = action["recipient"] || get_email_from_record(record)
    return false unless recipient.present?

    begin
      params = {
        "to_email" => recipient,
        "subject" => action["subject"] || "Thank you from our team",
        "body" => action["content"] || "Thank you for your business!"
      }
      tool = Tools::SendEmailTool.new(params, @user)
      result = tool.execute

      Rails.logger.info "✅ Sent proactive email to #{recipient}"
      true
    rescue => e
      Rails.logger.error "❌ Failed to send proactive email: #{e.message}"
      false
    end
  end

  def execute_create_task_action(action, record)
    begin
      params = {
        "title" => action["title"] || "Follow up task",
        "description" => action["description"] || "Auto-created proactive task",
        "priority" => "medium",
        "due_date" => 1.week.from_now.strftime("%Y-%m-%d")
      }
      tool = Tools::CreateTaskTool.new(params, @user)
      result = tool.execute

      Rails.logger.info "✅ Created proactive task: #{action['title']}"
      true
    rescue => e
      Rails.logger.error "❌ Failed to create proactive task: #{e.message}"
      false
    end
  end

  def execute_create_calendar_event_action(action, record)
    begin
      params = {
        "title" => action["title"] || "Follow up meeting",
        "start_time" => 1.week.from_now.strftime("%Y-%m-%d %H:%M"),
        "end_time" => (1.week.from_now + 1.hour).strftime("%Y-%m-%d %H:%M"),
        "description" => action["description"] || "Auto-created proactive event"
      }
      tool = Tools::CreateCalendarEventTool.new(params, @user)
      result = tool.execute

      Rails.logger.info "✅ Created proactive calendar event: #{action['title']}"
      true
    rescue => e
      Rails.logger.error "❌ Failed to create proactive calendar event: #{e.message}"
      false
    end
  end

  def get_email_from_record(record)
    case record
    when HubspotContact
      record.email
    when Email
      record.from_email
    else
      nil
    end
  end
end
