class AddFieldsToChats < ActiveRecord::Migration[8.0]
  def change
    add_reference :chats, :user, null: false, foreign_key: true
    add_column :chats, :title, :string
  end
end
