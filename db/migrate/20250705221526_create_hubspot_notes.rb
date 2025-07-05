class CreateHubspotNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :hubspot_notes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :hubspot_note_id
      t.string :hubspot_contact_id
      t.text :content
      t.datetime :created_date

      t.timestamps
    end
  end
end
