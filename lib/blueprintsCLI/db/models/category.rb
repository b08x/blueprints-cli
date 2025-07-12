# frozen_string_literal: true

require 'sequel'

# Represents a category that can be used to tag and organize blueprints.
class Category < Sequel::Model
  # Use the timestamps plugin to automatically manage created_at and updated_at fields.
  plugin :timestamps, update_on_create: true

  # Set up the many-to-many relationship with the Blueprint model.
  # The join table is implicitly assumed to be :blueprints_categories.
  many_to_many :blueprints
end
