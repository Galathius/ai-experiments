class RemoveEmbeddingFromEmailsAndCalendarEvents < ActiveRecord::Migration[8.0]
  def change
    remove_column :emails, :embedding, :vector if column_exists?(:emails, :embedding)
    remove_column :calendar_events, :embedding, :vector if column_exists?(:calendar_events, :embedding)
  end
end
