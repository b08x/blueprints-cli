# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:blueprints) do
      add_column :language, String, default: 'ruby'        # Programming language (ruby, python, javascript, etc.)
      add_column :file_type, String, default: '.rb'        # File extension (.rb, .py, .js, .yml, etc.)
      add_column :blueprint_type, String, default: 'code'  # High-level category (code, configuration, template, etc.)
      add_column :parser_type, String, default: 'ruby'     # Parser to use (ruby, ansible, react, python, etc.)

      add_index :blueprints, :language
      add_index :blueprints, :blueprint_type
      add_index :blueprints, :parser_type
    end
  end
end
