class CreateMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :messages do |t|
      t.references :chat, null: false, foreign_key: true
      t.text :content
      t.string :role

      t.timestamps
    end
  end
end
