class CreateHubspotContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :hubspot_contacts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :hubspot_contact_id
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :company
      t.string :phone
      t.text :notes

      t.timestamps
    end
  end
end
