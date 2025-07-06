class ToolRegistry
  def self.available_tools
    [
      {
        type: "function",
        function: {
          name: "send_email",
          description: "Send an email to a contact using Gmail",
          parameters: {
            type: "object",
            properties: {
              to_email: { 
                type: "string", 
                description: "Recipient email address" 
              },
              subject: { 
                type: "string", 
                description: "Email subject line" 
              },
              body: { 
                type: "string", 
                description: "Email content/message body" 
              }
            },
            required: ["to_email", "subject", "body"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "create_calendar_event",
          description: "Create a new calendar event/meeting in Google Calendar",
          parameters: {
            type: "object",
            properties: {
              title: { 
                type: "string", 
                description: "Event title/name" 
              },
              start_time: { 
                type: "string", 
                description: "Start time in ISO 8601 format (e.g., 2024-01-15T10:00:00)" 
              },
              duration_minutes: { 
                type: "integer", 
                description: "Duration in minutes (default: 60)",
                default: 60
              },
              attendees: { 
                type: "array", 
                items: { type: "string" },
                description: "List of attendee email addresses"
              },
              description: {
                type: "string",
                description: "Event description/details"
              }
            },
            required: ["title", "start_time"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "add_hubspot_note",
          description: "Add a note to a HubSpot contact",
          parameters: {
            type: "object",
            properties: {
              contact_email: {
                type: "string",
                description: "Email of the contact to add note to"
              },
              note_content: {
                type: "string", 
                description: "The note content to add"
              }
            },
            required: ["contact_email", "note_content"]
          }
        }
      }
    ]
  end
  
  def self.tool_names
    available_tools.map { |tool| tool[:function][:name] }
  end
  
  def self.get_tool_definition(tool_name)
    available_tools.find { |tool| tool[:function][:name] == tool_name }
  end
end