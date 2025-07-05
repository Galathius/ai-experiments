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
    
    vector = generate_embedding(content)
    return nil unless vector
    
    # Create or update the embedding record
    embedding_record = email.embedding || email.build_embedding
    embedding_record.update!(content: content, vector: vector)
    vector
  end
  
  def self.generate_embedding_for_calendar_event(calendar_event)
    content = calendar_event.content_for_embedding
    return nil if content.blank?
    
    vector = generate_embedding(content)
    return nil unless vector
    
    # Create or update the embedding record
    embedding_record = calendar_event.embedding || calendar_event.build_embedding
    embedding_record.update!(content: content, vector: vector)
    vector
  end
  
  def self.generate_embedding_for(embeddable)
    content = embeddable.content_for_embedding
    return nil if content.blank?
    
    vector = generate_embedding(content)
    return nil unless vector
    
    # Create or update the embedding record
    embedding_record = embeddable.embedding || embeddable.build_embedding
    embedding_record.update!(content: content, vector: vector)
    vector
  end
end
