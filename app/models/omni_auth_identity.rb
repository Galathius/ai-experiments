class OmniAuthIdentity < ApplicationRecord
  belongs_to :user
  
  validates :provider, presence: true
  validates :uid, presence: true
  validates :provider, uniqueness: { scope: :user_id }
  
  def google?
    provider == 'google_oauth2'
  end
  
  def hubspot?
    provider == 'hubspot'
  end
  
  def access_token
    token
  end
  
  def refresh_token
    refresh_token_value
  end
end
