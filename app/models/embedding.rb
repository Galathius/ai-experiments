class Embedding < ApplicationRecord
  belongs_to :embeddable, polymorphic: true

  has_neighbors :vector

  validates :content, presence: true
  validates :vector, presence: true
  validates :embeddable_id, uniqueness: { scope: :embeddable_type }

  scope :for_emails, -> { where(embeddable_type: "Email") }
  scope :for_calendar_events, -> { where(embeddable_type: "CalendarEvent") }
  scope :for_hubspot_contacts, -> { where(embeddable_type: "HubspotContact") }
  scope :for_hubspot_notes, -> { where(embeddable_type: "HubspotNote") }

  def self.semantic_search(query, limit: 10, types: nil)
    query_vector = EmbeddingService.generate_embedding(query)
    return none unless query_vector

    scope = all
    scope = scope.where(embeddable_type: types) if types.present?

    scope.nearest_neighbors(:vector, query_vector, distance: :cosine).limit(limit)
  end

  def self.search_across_all_content(query, limit: 10)
    semantic_search(query, limit: limit)
  end
end
