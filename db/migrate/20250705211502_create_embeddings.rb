class CreateEmbeddings < ActiveRecord::Migration[8.0]
  def change
    create_table :embeddings do |t|
      t.references :embeddable, polymorphic: true, null: false
      t.text :content, null: false
      t.vector :vector, limit: 1536, null: false

      t.timestamps
    end

    add_index :embeddings, [ :embeddable_type, :embeddable_id ], unique: true
    add_index :embeddings, :vector, using: :ivfflat, opclass: :vector_cosine_ops
  end
end
