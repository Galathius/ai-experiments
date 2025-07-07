class AddInitialSyncFlagsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :hubspot_contacts_initial_sync_complete, :boolean, default: false
    add_column :users, :hubspot_notes_initial_sync_complete, :boolean, default: false
  end
end
