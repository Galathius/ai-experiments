class CreateEmails < ActiveRecord::Migration[8.0]
  def change
    create_table :emails do |t|
      t.references :user, null: false, foreign_key: true
      t.string :gmail_id, null: false
      t.text :subject
      t.text :body
      t.string :from_email
      t.text :to_email
      t.text :cc_email
      t.text :bcc_email
      t.datetime :received_at
      t.string :thread_id
      t.text :labels
      t.vector :embedding, limit: 1536

      t.timestamps
    end
    
    add_index :emails, :gmail_id, unique: true
    add_index :emails, :thread_id
    add_index :emails, :received_at
    add_index :emails, :from_email
    add_index :emails, :embedding, using: :ivfflat, opclass: :vector_cosine_ops
  end
end
