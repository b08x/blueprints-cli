# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:blueprints) do
      primary_key :id
      String :name, text: true
      String :description, text: true
      String :code, text: true
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
