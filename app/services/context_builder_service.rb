class ContextBuilderService
  def initialize(query)
    @query = query
  end

  def build_context
    relevant_embeddings = Embedding.semantic_search(@query, limit: 8)
    context_items = []

    relevant_embeddings.each do |embedding|
      context_item = build_context_item(embedding)
      context_items << context_item if context_item
    end

    context_items
  end

  private

  def build_context_item(embedding)
    case embedding.embeddable_type
    when "Email"
      build_email_context(embedding)
    when "CalendarEvent"
      build_calendar_event_context(embedding)
    when "HubspotContact"
      build_hubspot_contact_context(embedding)
    when "HubspotNote"
      build_hubspot_note_context(embedding)
    end
  end

  def build_email_context(embedding)
    email = embedding.embeddable
    {
      type: "email",
      from: email.from_name || email.from_email,
      from_email: email.from_email,
      subject: email.subject,
      date: email.received_at,
      content: email.body.to_s.truncate(300),
      relevance_score: embedding.vector ? "high" : "medium"
    }
  end

  def build_calendar_event_context(embedding)
    event = embedding.embeddable
    {
      type: "calendar_event",
      title: event.title,
      start_time: event.start_time,
      end_time: event.end_time,
      location: event.location,
      attendees: event.attendees_array,
      description: event.description.to_s.truncate(200),
      relevance_score: embedding.vector ? "high" : "medium"
    }
  end

  def build_hubspot_contact_context(embedding)
    contact = embedding.embeddable
    {
      type: "hubspot_contact",
      name: contact.full_name,
      email: contact.email,
      company: contact.company,
      phone: contact.phone,
      relevance_score: embedding.vector ? "high" : "medium"
    }
  end

  def build_hubspot_note_context(embedding)
    note = embedding.embeddable
    {
      type: "hubspot_note",
      content: note.content.to_s.truncate(300),
      created_date: note.created_date,
      contact_name: note.hubspot_contact&.full_name,
      contact_email: note.hubspot_contact&.email,
      relevance_score: embedding.vector ? "high" : "medium"
    }
  end
end
