class SystemPromptService
  def initialize(context_items, user)
    @context_items = context_items
    @user = user
  end

  def build_prompt
    base_prompt = build_base_prompt
    base_prompt += build_task_context
    base_prompt += build_context_section
    base_prompt += build_instructions
    base_prompt += build_formatting_instructions
    base_prompt
  end

  private

  def build_base_prompt
    current_time = Time.current.strftime("%A, %B %d, %Y at %I:%M %p %Z")
    "You are an AI assistant for a financial advisor. You help with managing emails, calendar events, client relationships, HubSpot CRM data, and task management. You have access to the user's email, calendar, HubSpot contact/notes data, and task information to provide informed responses.\n\nCurrent date and time: #{current_time}\n\n"
  end

  def build_task_context
    prompt = "You can perform actions like:\n"
    prompt += "- Send emails using send_email\n"
    prompt += "- Create calendar events using create_calendar_event\n"
    prompt += "- Add notes to HubSpot contacts using add_hubspot_note\n"
    prompt += "- Create tasks using create_task\n"
    prompt += "- List and filter tasks using list_tasks\n"
    prompt += "- Update task details using update_task\n"
    prompt += "- Mark tasks as completed using complete_task\n\n"

    task_context = get_task_context
    if task_context.present?
      prompt += "CURRENT TASK STATUS:\n#{task_context}\n\n"
    end

    prompt
  end

  def build_context_section
    return "No specific context was found for this query, but you can still provide helpful assistance based on your general knowledge.\n\n" unless @context_items.any?

    prompt = "Here is relevant context from the user's emails, calendar, and HubSpot CRM:\n\n"

    @context_items.each_with_index do |item, index|
      prompt += format_context_item(item, index)
    end

    prompt
  end

  def format_context_item(item, index)
    case item[:type]
    when "email"
      format_email_context(item, index)
    when "calendar_event"
      format_calendar_event_context(item, index)
    when "hubspot_contact"
      format_hubspot_contact_context(item, index)
    when "hubspot_note"
      format_hubspot_note_context(item, index)
    else
      ""
    end
  end

  def format_email_context(item, index)
    prompt = "EMAIL #{index + 1}:\n"
    prompt += "From: #{item[:from]} (#{item[:from_email]})\n"
    prompt += "Subject: #{item[:subject]}\n"
    prompt += "Date: #{item[:date].strftime('%B %d, %Y')}\n"
    prompt += "Content: #{item[:content]}\n\n"
    prompt
  end

  def format_calendar_event_context(item, index)
    prompt = "CALENDAR EVENT #{index + 1}:\n"
    prompt += "Title: #{item[:title]}\n"
    prompt += "Date: #{item[:start_time].strftime('%B %d, %Y at %I:%M %p')}\n"
    prompt += "Location: #{item[:location]}\n" if item[:location].present?
    prompt += "Attendees: #{item[:attendees].join(', ')}\n" if item[:attendees].any?
    prompt += "Description: #{item[:description]}\n" if item[:description].present?
    prompt += "\n"
    prompt
  end

  def format_hubspot_contact_context(item, index)
    prompt = "HUBSPOT CONTACT #{index + 1}:\n"
    prompt += "Name: #{item[:name]}\n"
    prompt += "Email: #{item[:email]}\n" if item[:email].present?
    prompt += "Company: #{item[:company]}\n" if item[:company].present?
    prompt += "Phone: #{item[:phone]}\n" if item[:phone].present?
    prompt += "Notes: #{item[:notes]}\n" if item[:notes].present?
    prompt += "\n"
    prompt
  end

  def format_hubspot_note_context(item, index)
    prompt = "HUBSPOT NOTE #{index + 1}:\n"
    prompt += "Date: #{item[:created_date].strftime('%B %d, %Y')}\n" if item[:created_date]
    prompt += "About: #{item[:contact_name]} (#{item[:contact_email]})\n" if item[:contact_name].present?
    prompt += "Content: #{item[:content]}\n"
    prompt += "\n"
    prompt
  end

  def build_instructions
    prompt = "Instructions:\n"
    prompt += "- Use the provided context to give accurate, specific answers\n"
    prompt += "- If asked about people, reference their emails or calendar events\n"
    prompt += "- Be helpful and professional\n"
    prompt += "- If you don't have enough information, say so clearly\n"
    prompt += "- For scheduling requests, mention you'd need calendar access to check availability\n\n"
    prompt
  end

  def build_formatting_instructions
    prompt = "SPECIAL FORMATTING for calendar events:\n"
    prompt += "When showing calendar events, use this exact format so they render as cards:\n"
    prompt += "[CALENDAR_EVENTS]\n"
    prompt += "- event_id: unique_id | title: Event Title | start: YYYY-MM-DD HH:MM | end: YYYY-MM-DD HH:MM | location: Location\n"
    prompt += "[/CALENDAR_EVENTS]\n"
    prompt += "Always include this formatting when listing calendar events.\n"
    prompt
  end

  def get_task_context
    task_manager = TaskManager.new(@user)
    task_manager.get_context_for_ai
  end
end
