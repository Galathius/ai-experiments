class HubspotNote < ApplicationRecord
  belongs_to :user
  belongs_to :hubspot_contact, optional: true
  has_one :embedding, as: :embeddable, dependent: :destroy

  validates :hubspot_note_id, presence: true, uniqueness: { scope: :user_id }
  validates :content, presence: true

  def content_for_embedding
    content_parts = []
    content_parts << "Note created: #{created_date.strftime('%B %d, %Y')}" if created_date
    if hubspot_contact
      content_parts << "About: #{hubspot_contact.full_name}"
      content_parts << "Contact Email: #{hubspot_contact.email}" if hubspot_contact.email.present?
    end
    content_parts << "Content: #{content}"

    content_parts.join("\n")
  end
end
