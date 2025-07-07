class CreateCalendars < ActiveRecord::Migration[8.0]
  def change
    create_table :calendars do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :next_page_token
      t.datetime :last_sync_at
      t.string :sync_status, default: 'idle'
      t.text :last_error
      t.string :last_sync_token

      t.timestamps
    end
  end
end
