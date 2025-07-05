class GenerateEmbeddingJob < ApplicationJob
  queue_as :default

  def perform(embeddable)
    # Check if embedding already exists
    return if embeddable.embedding.present?
    
    # Generate content for embedding
    content = embeddable.content_for_embedding
    return if content.blank?
    
    # Generate embedding vector
    vector = EmbeddingService.generate_embedding(content)
    return unless vector
    
    # Create embedding record
    embeddable.create_embedding!(
      content: content,
      vector: vector
    )
    
    Rails.logger.info "Generated embedding for #{embeddable.class.name} #{embeddable.id}"
  rescue => e
    Rails.logger.error "Failed to generate embedding for #{embeddable.class.name} #{embeddable.id}: #{e.message}"
    raise e
  end
end