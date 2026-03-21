# frozen_string_literal: true

# Migration to clear existing Google text-embedding-004 embeddings
# in preparation for switching to Ollama embeddinggemma:latest model.
#
# This migration sets all existing embeddings to NULL so they can be
# regenerated using the new Ollama model, ensuring consistency across
# all embeddings in the database.

Sequel.migration do
  up do
    # Clear all existing embeddings
    # These will be regenerated using the new Ollama embedding model
    self[:blueprints].update(embedding: nil)

    # Log the migration
    puts "Cleared all existing Google embeddings from blueprints table"
    puts "Run 'bin/blueprintsCLI embedding process' to regenerate with Ollama"
  end

  down do
    # Cannot recover the original Google embeddings
    puts "WARNING: Cannot restore original Google embeddings"
    puts "This migration is not reversible - embeddings must be regenerated"
  end
end