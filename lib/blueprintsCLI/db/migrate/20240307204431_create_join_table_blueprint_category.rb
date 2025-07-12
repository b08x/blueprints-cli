# frozen_string_literal: true

Sequel.migration do
  change do
    # This migration creates the join table for the many-to-many relationship
    # between blueprints and categories.
    create_table(:blueprints_categories) do
      # Foreign keys to link to the blueprints and categories tables.
      foreign_key :blueprint_id, :blueprints, null: false, on_delete: :cascade
      foreign_key :category_id, :categories, null: false, on_delete: :cascade

      # A composite primary key to ensure that each blueprint-category pair is unique.
      primary_key %i[blueprint_id category_id]

      # An index to speed up queries on the join table.
      index %i[blueprint_id category_id]
    end
  end
end
