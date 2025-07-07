class AddInitialSyncCompleteToCalendars < ActiveRecord::Migration[8.0]
  def change
    add_column :calendars, :initial_sync_complete, :boolean, default: false
  end
end
