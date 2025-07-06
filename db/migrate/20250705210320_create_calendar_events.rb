class CreateCalendarEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :calendar_events do |t|
      t.references :user, null: false, foreign_key: true
      t.string :google_event_id, null: false
      t.text :title
      t.text :description
      t.datetime :start_time, null: false
      t.datetime :end_time
      t.string :location
      t.text :attendees
      t.string :creator_email
      t.string :status
      t.vector :embedding, limit: 1536

      t.timestamps
    end

    add_index :calendar_events, :google_event_id, unique: true
    add_index :calendar_events, :start_time
    add_index :calendar_events, :end_time
    add_index :calendar_events, :status
    add_index :calendar_events, :embedding, using: :ivfflat, opclass: :vector_cosine_ops
  end
end
