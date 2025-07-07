class CreateMailboxes < ActiveRecord::Migration[8.0]
  def change
    create_table :mailboxes do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :next_page_token
      t.datetime :last_sync_at
      t.string :sync_status, default: 'idle'
      t.text :last_error

      t.timestamps
    end
  end
end
