class AddTokensToOmniAuthIdentities < ActiveRecord::Migration[8.0]
  def change
    add_column :omni_auth_identities, :access_token, :text
    add_column :omni_auth_identities, :refresh_token, :text
    add_column :omni_auth_identities, :expires_at, :datetime
  end
end
