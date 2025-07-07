class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :status, default: 'pending'
      t.string :priority, default: 'medium'
      t.datetime :due_date
      t.datetime :completed_at
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :tasks, [ :user_id, :status ]
    add_index :tasks, :due_date
    add_index :tasks, :priority
    add_index :tasks, :metadata, using: :gin
  end
end
