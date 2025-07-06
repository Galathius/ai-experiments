class RemoveNotesFromHubspotContacts < ActiveRecord::Migration[8.0]
  def change
    remove_column :hubspot_contacts, :notes, :text
  end
end
