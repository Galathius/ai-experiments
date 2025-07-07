class User < ApplicationRecord
  has_many :sessions, dependent: :destroy
  has_many :omni_auth_identities, dependent: :destroy
  has_many :chats, dependent: :destroy
  has_many :emails, dependent: :destroy
  has_many :calendar_events, dependent: :destroy
  has_many :hubspot_contacts, dependent: :destroy
  has_many :hubspot_notes, dependent: :destroy
  has_many :action_logs, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_one :mailbox, dependent: :destroy
  has_one :calendar, dependent: :destroy

  validates :email_address, presence: true,
    format: { with: URI::MailTo::EMAIL_REGEXP },
    uniqueness: { case_sensitive: false }

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  def self.create_from_oauth(auth)
    email = auth.info.email
    user = self.new email_address: email
    assign_names_from_auth(auth, user)
    user.save!
    user
  end

  def signed_in_with_oauth(auth)
    User.assign_names_from_auth(auth, self)
    save if first_name_changed? || last_name_changed?
  end

  def google_identity
    omni_auth_identities.find_by(provider: "google_oauth2")
  end

  def hubspot_identity
    omni_auth_identities.find_by(provider: "hubspot")
  end

  def connected_to_hubspot?
    hubspot_identity.present?
  end

  def get_or_create_mailbox
    mailbox || create_mailbox!
  end

  def get_or_create_calendar
    calendar || create_calendar!
  end

  private

  def self.assign_names_from_auth(auth, user)
    provider = auth["provider"]
    case provider
    when "developer"
      if user.first_name.blank? && user.last_name.blank?
        user.first_name = auth.info.name
        user.last_name = "Developer"
      end
    when "google_oauth2"
      if user.first_name.blank? && user.last_name.blank?
        user.first_name = auth.info.first_name
        user.last_name = auth.info.last_name
      end
    end
  end
end
