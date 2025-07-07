class AddInitialSyncCompleteToMailboxes < ActiveRecord::Migration[8.0]
  def change
    add_column :mailboxes, :initial_sync_complete, :boolean, default: false
  end
end
