# frozen_string_literal: true

Sequel.migration do
  up do
    create_table(:blueprint_categories) do
      foreign_key :blueprint_id, :blueprints, null: false, on_delete: :cascade
      foreign_key :category_id, :categories, null: false, on_delete: :cascade

      primary_key %i[blueprint_id category_id]

      index :blueprint_id
      index :category_id
    end
  end

  down do
    drop_table(:blueprint_categories)
  end
end
