# frozen_string_literal: true

Sequel.migration do
  change do
    # This migration adds the `embedding` column to the `blueprints` table.
    # The column type is `vector(768)`, which is provided by the pgvector extension.
    # The number 768 corresponds to the dimensions of the embeddings generated
    # by the "text-embedding-004" model from Google Gemini.
    add_column :blueprints, :embedding, 'vector(768)'
  end
end
