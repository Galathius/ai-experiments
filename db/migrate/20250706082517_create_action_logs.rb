class CreateActionLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :action_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :tool_name
      t.jsonb :parameters
      t.jsonb :result

      t.timestamps
    end
  end
end
