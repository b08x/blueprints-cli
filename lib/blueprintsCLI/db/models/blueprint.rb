# frozen_string_literal: true

# app/models/blueprint.rb

require 'sequel'
require 'pgvector'

# Represents a single code blueprint in the database.
# This model includes logic for timestamping, associations, and vector-based search.
class Blueprint < Sequel::Model
  # Use the timestamps plugin to automatically manage created_at and updated_at fields.
  plugin :timestamps, update_on_create: true

  # Set up the many-to-many relationship with the Category model.
  # The join table is implicitly assumed to be :blueprints_categories.
  many_to_many :categories

  # Performs a search for blueprints.
  # If a query is provided, it performs a semantic vector search.
  # Otherwise, it returns the most recently created blueprints.
  #
  # @param query [String, nil] The search term.
  # @return [Sequel::Dataset] A dataset of blueprints.
  def self.search(query)
    if query && !query.strip.empty?
      # Generate an embedding for the search query.
      embedding = RubyLLM.embed(text: query)

      # Use the pgvector cosine distance operator (<->) to find the nearest neighbors.
      # The results are ordered by their distance to the query embedding (lower is better).
      order(Sequel.lit('embedding <-> ?', Pgvector.encode(embedding))).limit(20)
    else
      # If no query is provided, return the 20 most recent blueprints.
      order(Sequel.desc(:created_at)).limit(20)
    end
  end
end
