class HubspotContact < ApplicationRecord
  belongs_to :user
  has_many :hubspot_notes, dependent: :destroy
  has_one :embedding, as: :embeddable, dependent: :destroy
  
  validates :hubspot_contact_id, presence: true, uniqueness: { scope: :user_id }
  
  def full_name
    [first_name, last_name].compact.join(' ')
  end
  
  def content_for_embedding
    content_parts = []
    content_parts << "Contact: #{full_name}" if full_name.present?
    content_parts << "Email: #{email}" if email.present?
    content_parts << "Company: #{company}" if company.present?
    content_parts << "Phone: #{phone}" if phone.present?
    content_parts << "Notes: #{notes}" if notes.present?
    
    content_parts.join("\n")
  end
end
