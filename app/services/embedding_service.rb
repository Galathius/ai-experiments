class EmbeddingService
  def self.generate_embedding(text)
    return nil if text.blank?
    
    client = OpenAI::Client.new(access_token: Rails.application.credentials.openai.api_key)
    
    response = client.embeddings(
      parameters: {
        model: 'text-embedding-ada-002',
        input: text.strip
      }
    )
    
    response.dig('data', 0, 'embedding')
  end
  
  def self.generate_embedding_for_email(email)
    content = email.content_for_embedding
    return nil if content.blank?
    
    embedding = generate_embedding(content)
    return nil unless embedding
    
    email.update!(embedding: embedding)
    embedding
  end
  
  def self.generate_embedding_for_calendar_event(calendar_event)
    content = calendar_event.content_for_embedding
    return nil if content.blank?
    
    embedding = generate_embedding(content)
    return nil unless embedding
    
    calendar_event.update!(embedding: embedding)
    embedding
  end
end
