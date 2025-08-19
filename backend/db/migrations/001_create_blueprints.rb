# frozen_string_literal: true

Sequel.migration do
  up do
    # Enable pgvector extension
    run 'CREATE EXTENSION IF NOT EXISTS vector'

    create_table(:blueprints) do
      primary_key :id
      String :name, null: false, unique: true
      Text :description, null: false
      Text :code, null: false
      String :language, default: 'javascript'
      String :framework
      String :type

      # Vector embedding for similarity search
      column :embedding, 'vector(384)', null: true

      DateTime :created_at, null: false
      DateTime :updated_at, null: false

      index :name
      index :language
      index :framework
      index :type
      index :created_at

      # Vector similarity search index
      index :embedding, type: :ivfflat, opclass: :vector_cosine_ops
    end
  end

  down do
    drop_table(:blueprints)
    run 'DROP EXTENSION IF EXISTS vector'
  end
end
