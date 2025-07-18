class Sessions::OmniAuthsController < ApplicationController
  allow_unauthenticated_access only: [ :create, :failure ]

  def create
    auth = request.env["omniauth.auth"]
    uid = auth["uid"]
    provider = auth["provider"]
    redirect_path = request.env["omniauth.params"]&.dig("origin") || root_path

    identity = OmniAuthIdentity.find_by(uid: uid, provider: provider)
    if authenticated?
      # User is signed in so they are trying to link an identity with their account
      if identity.nil?
        # No identity was found, create a new one for this user
        identity = create_identity_with_tokens(uid, provider, Current.user, auth)
        # Give the user model the option to update itself with the new information
        Current.user.signed_in_with_oauth(auth)
        redirect_to redirect_path, notice: "Account linked!"
      else
        # Identity was found, nothing to do
        # Check relation to current user
        if Current.user == identity.user
          redirect_to redirect_path, notice: "Already linked that account!"
        else
          # The identity is not associated with the current_user, illegal state
          redirect_to redirect_path, notice: "Account mismatch, try signing out first!"
        end
      end
    else
      # Check if identity was found i.e. user has visited the site before
      if identity.nil?
        # New identity visiting the site, we are linking to an existing User or creating a new one
        user = User.find_by(email_address: auth.info.email) || User.create_from_oauth(auth)
        identity = create_identity_with_tokens(uid, provider, user, auth)
      else
        # Update existing identity with new tokens
        update_identity_tokens(identity, auth)
      end
      start_new_session_for identity.user, source: provider
      redirect_to redirect_path, notice: "Signed in!"
    end
  end

  def failure
    redirect_to new_session_path, alert: "Authentication failed, please try again."
  end

  private

  def create_identity_with_tokens(uid, provider, user, auth)
    OmniAuthIdentity.create!(
      uid: uid,
      provider: provider,
      user: user,
      access_token: auth.credentials&.token,
      refresh_token: auth.credentials&.refresh_token,
      expires_at: auth.credentials&.expires_at ? Time.at(auth.credentials.expires_at) : nil
    )
  end

  def update_identity_tokens(identity, auth)
    identity.update!(
      access_token: auth.credentials&.token,
      refresh_token: auth.credentials&.refresh_token || identity.refresh_token,
      expires_at: auth.credentials&.expires_at ? Time.at(auth.credentials.expires_at) : nil
    )
  end
end
