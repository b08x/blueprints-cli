# frozen_string_literal: true

Sequel.migration do
  up do
    # This migration enables the pgvector extension in the PostgreSQL database.
    # The `IF NOT EXISTS` clause prevents an error if the extension is already enabled.
    run 'CREATE EXTENSION IF NOT EXISTS vector;'
  end

  down do
    # This block defines how to reverse the migration.
    run 'DROP EXTENSION IF EXISTS vector;'
  end
end
