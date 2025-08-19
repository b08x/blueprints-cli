# frozen_string_literal: true

Sequel.migration do
  up do
    create_table(:categories) do
      primary_key :id
      String :name, null: false, unique: true
      String :description

      DateTime :created_at, null: false
      DateTime :updated_at, null: false

      index :name
    end
  end

  down do
    drop_table(:categories)
  end
end
