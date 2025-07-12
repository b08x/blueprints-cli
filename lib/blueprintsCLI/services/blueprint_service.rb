# frozen_string_literal: true

# app/services/blueprint_service.rb

require_relative '../models/blueprint'
require_relative '../models/category'
require 'ruby_llm'
require 'pgvector'

# This service encapsulates the business logic for managing blueprints.
# It handles the creation and searching of blueprints, interacting with
# the database models and the LLM for embedding generation.
class BlueprintService
  # Searches for blueprints based on a query.
  #
  # @param query [String, nil] The search term.
  # @return [Array<Hash>] An array of blueprint data.
  def search(query)
    Blueprint.search(query).map(&:to_hash)
  end

  # Creates a new blueprint with the given parameters.
  #
  # @param params [Hash] A hash containing the blueprint data.
  #   - "name" [String] The name of the blueprint.
  #   - "description" [String] The description of the blueprint.
  #   - "code" [String] The code of the blueprint.
  #   - "categories" [Array<String>] A list of category names.
  # @return [Hash] The created blueprint data.
  def create(params)
    # The creation process is wrapped in a database transaction to ensure atomicity.
    # If any step fails, all changes are rolled back.
    DB.transaction do
      # Create a new Blueprint instance.
      blueprint = Blueprint.new(
        name: params['name'],
        description: params['description'],
        code: params['code']
      )

      # Generate a vector embedding from the name and description for semantic search.
      embedding_text = "#{params['name']} #{params['description']}"
      embedding = RubyLLM.embed(text: embedding_text)
      blueprint.embedding = Pgvector.encode(embedding)

      # Save the blueprint to the database.
      blueprint.save

      # Process and associate categories if they are provided.
      if params['categories'] && params['categories'].is_a?(Array)
        params['categories'].each do |category_name|
          # Find an existing category or create a new one.
          # This prevents duplicate categories.
          category = Category.find_or_create(name: category_name)
          # Associate the category with the blueprint.
          blueprint.add_category(category)
        end
      end

      # Reload the blueprint to include associations and return its hash representation.
      blueprint.refresh.to_hash.merge(categories: blueprint.categories.map(&:to_hash))
    end
  end
end
