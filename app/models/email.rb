class Email < ApplicationRecord
  belongs_to :user
  has_one :embedding, as: :embeddable, dependent: :destroy

  validates :gmail_id, presence: true, uniqueness: true
  validates :from_email, presence: true
  validates :received_at, presence: true

  scope :recent, -> { order(received_at: :desc) }
  scope :from_sender, ->(email) { where(from_email: email) }
  scope :in_thread, ->(thread_id) { where(thread_id: thread_id) }

  def content_for_embedding
    parts = []

    # Add sender information
    parts << "From: #{from_name}" if from_name.present?
    parts << "Sender: #{from_email}" if from_email.present?

    # Add recipient information
    if to_email.present?
      to_names = extract_names_from_addresses(to_email)
      parts << "To: #{to_names.join(', ')}"
    end

    if cc_email.present?
      cc_names = extract_names_from_addresses(cc_email)
      parts << "CC: #{cc_names.join(', ')}"
    end

    # Add subject and body
    parts << "Subject: #{subject}" if subject.present?
    parts << body if body.present?

    # Add labels as context
    if labels_array.any?
      parts << "Labels: #{labels_array.join(', ')}"
    end

    parts.compact.join(" ")
  end

  def from_name
    # Extract name from "Name <email@domain.com>" format
    match = from_email.match(/^(.+?)\s*</)
    match ? match[1].strip : from_email
  end

  def labels_array
    labels.present? ? labels.split(",").map(&:strip) : []
  end

  private

  def extract_names_from_addresses(address_string)
    return [] if address_string.blank?

    # Split multiple addresses and extract names
    addresses = address_string.split(",").map(&:strip)
    addresses.map do |addr|
      # Extract name from "Name <email@domain.com>" format
      if match = addr.match(/^(.+?)\s*</)
        match[1].strip
      else
        addr.split("@").first # Use email username if no name
      end
    end
  end


  def self.semantic_search(query, limit: 10)
    # This will be used for RAG - find emails similar to the query
    embeddings = Embedding.semantic_search(query, limit: limit, types: [ "Email" ])
    email_ids = embeddings.pluck(:embeddable_id)
    where(id: email_ids)
  end
end
