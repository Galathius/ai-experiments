class OmniAuthIdentity < ApplicationRecord
  belongs_to :user

  validates :provider, presence: true
  validates :uid, presence: true
  validates :provider, uniqueness: { scope: :user_id }

  def google?
    provider == "google_oauth2"
  end

  def hubspot?
    provider == "hubspot"
  end

  # access_token and refresh_token are already column names, no need for custom methods
end
