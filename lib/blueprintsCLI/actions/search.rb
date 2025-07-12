# frozen_string_literal: true

require 'tty-box'

module BlueprintsCLI
  module Actions
    ##
    # Search provides search functionality for blueprints in the system.
    # It supports both semantic vector-based search and traditional text search,
    # allowing developers to find relevant blueprints based on their queries.
    #
    # This action is typically used when users need to locate specific blueprints
    # by name, description, code content, or semantic similarity.
    #
    # @example Basic semantic search
    #   action = Search.new(query: "user authentication")
    #   action.call
    #
    # @example Text search with custom limit
    #   action = Search.new(query: "database connection", semantic: false, limit: 5)
    #   action.call
    class Search < Sublayer::Actions::Base
      ##
      # Initializes a new Search with search parameters.
      #
      # @param [String] query The search term to look for in blueprints
      # @param [Integer] limit The maximum number of results to return (default: 10)
      # @param [Boolean] semantic Whether to use semantic search (default: true)
      # @return [Search] A new instance of Search
      def initialize(query:, limit: 10, semantic: true)
        @query = query
        @limit = limit
        @semantic = semantic
        @db = BlueprintsCLI::BlueprintDatabase.new
      end

      ##
      # Executes the blueprint search based on the configured parameters.
      #
      # This method coordinates the search process, displays results, and handles
      # any errors that might occur during the search operation.
      #
      # @return [Boolean] true if the search completed successfully, false if an error occurred
      def call
        puts "🔍 Searching for: '#{@query}'...".colorize(:blue)

        results = if @semantic
                    semantic_search
                  else
                    text_search
                  end

        if results.empty?
          puts "📭 No blueprints found matching '#{@query}'".colorize(:yellow)
          return true
        end

        puts "✅ Found #{results.length} matching blueprints".colorize(:green)
        display_search_results(results)

        true
      rescue StandardError => e
        BlueprintsCLI.logger.failure("Error searching blueprints: #{e.message}")
        BlueprintsCLI.logger.debug(e) if ENV['DEBUG']
        false
      end

      private

      ##
      # Performs a semantic search using vector similarity.
      #
      # This method uses the database's vector similarity search capability
      # to find blueprints that are semantically similar to the query.
      #
      # @return [Array<Hash>] An array of blueprint hashes with similarity scores
      def semantic_search
        # Use vector similarity search for semantic matching
        @db.search_blueprints(query: @query, limit: @limit)
      end

      ##
      # Performs a traditional text-based search across blueprint fields.
      #
      # This method searches for the query terms in blueprint names, descriptions,
      # code content, and categories. It implements a simple relevance scoring
      # system to rank results.
      #
      # @return [Array<Hash>] An array of matching blueprint hashes
      def text_search
        # Fallback to simple text search in name, description, and code
        blueprints = @db.list_blueprints(limit: 1000) # Get more for filtering

        query_words = @query.downcase.split(/\s+/)

        results = blueprints.select do |blueprint|
          searchable_text = [
            blueprint[:name],
            blueprint[:description],
            blueprint[:code],
            blueprint[:categories].map { |c| c[:title] }.join(' ')
          ].compact.join(' ').downcase

          # Check if all query words are present
          query_words.all? { |word| searchable_text.include?(word) }
        end

        # Sort by relevance (simple scoring)
        results.sort_by do |blueprint|
          score = calculate_text_relevance(blueprint, query_words)
          -score # Negative for descending order
        end.first(@limit)
      end

      ##
      # Calculates a relevance score for a blueprint based on query word matches.
      #
      # This method assigns different weights to matches in different fields:
      # - Name matches: 10 points
      # - Description matches: 5 points
      # - Code matches: 1 point
      #
      # @param [Hash] blueprint The blueprint to score
      # @param [Array<String>] query_words The query terms to match against
      # @return [Integer] The calculated relevance score
      def calculate_text_relevance(blueprint, query_words)
        score = 0

        # Higher weight for matches in name and description
        name_text = (blueprint[:name] || '').downcase
        desc_text = (blueprint[:description] || '').downcase
        code_text = blueprint[:code].downcase

        query_words.each do |word|
          score += 10 if name_text.include?(word)
          score += 5 if desc_text.include?(word)
          score += 1 if code_text.include?(word)
        end

        score
      end

      ##
      # Displays the search results in a formatted table.
      #
      # This method handles both semantic search results (with similarity scores)
      # and traditional text search results, formatting them appropriately
      # for console display.
      #
      # @param [Array<Hash>] results The search results to display
      def display_search_results(results)
        # Display header using TTY::Box
        header_box = TTY::Box.frame(
          "🔍 Search Results for: '#{@query}'",
          width: 120,
          align: :center,
          style: { border: { fg: :blue } }
        )
        puts "\n#{header_box}"

        if @semantic && results.first && results.first.key?(:distance)
          # Show similarity scores for semantic search
          printf "%-5s %-30s %-40s %-20s %-10s\n", 'ID', 'Name', 'Description', 'Categories',
                 'Score'
          puts '-' * 120

          results.each do |blueprint|
            name = truncate_text(blueprint[:name] || 'Untitled', 28)
            description = truncate_text(blueprint[:description] || 'No description', 38)
            categories = get_category_text(blueprint[:categories])
            similarity = calculate_similarity_percentage(blueprint[:distance])

            printf "%-5s %-30s %-40s %-20s %-10s\n",
                   blueprint[:id],
                   name,
                   description,
                   categories,
                   "#{similarity}%"
          end
        else
          # Standard display for text search
          printf "%-5s %-35s %-50s %-25s\n", 'ID', 'Name', 'Description', 'Categories'
          puts '-' * 120

          results.each do |blueprint|
            name = truncate_text(blueprint[:name] || 'Untitled', 33)
            description = truncate_text(blueprint[:description] || 'No description', 48)
            categories = get_category_text(blueprint[:categories])

            printf "%-5s %-35s %-50s %-25s\n",
                   blueprint[:id],
                   name,
                   description,
                   categories
          end
        end

        puts '=' * 120
        puts ''

        # Show usage hints
        show_usage_hints(results)
      end

      ##
      # Converts a similarity distance to a percentage.
      #
      # Lower distance values indicate higher similarity, so this method
      # converts the distance to a more intuitive percentage score.
      #
      # @param [Float] distance The similarity distance from the semantic search
      # @return [Float] The similarity percentage (0-100)
      def calculate_similarity_percentage(distance)
        # Convert distance to percentage (lower distance = higher similarity)
        # This is a rough approximation - adjust based on your embedding space
        similarity = [100 - (distance * 100), 0].max
        similarity.round(1)
      end

      ##
      # Formats category information for display.
      #
      # @param [Array<Hash>, nil] categories The categories to format
      # @return [String] A formatted string of category names
      def get_category_text(categories)
        return 'None' if categories.nil? || categories.empty?

        category_names = categories.map { |cat| cat[:title] }
        text = category_names.join(', ')
        truncate_text(text, 23)
      end

      ##
      # Displays helpful usage hints after search results.
      #
      # @param [Array<Hash>] results The search results that were displayed
      def show_usage_hints(results)
        puts '💡 Next steps:'.colorize(:cyan)
        puts '   blueprint view <id>           View full blueprint details'
        puts '   blueprint view <id> --analyze Get AI analysis and suggestions'
        puts '   blueprint edit <id>           Edit a blueprint'
        puts '   blueprint export <id>         Export blueprint code'

        if results.any?
          sample_id = results.first[:id]
          puts "\n📋 Example: blueprint view #{sample_id}".colorize(:yellow)
        end
        puts ''
      end

      ##
      # Truncates text to fit within a specified length.
      #
      # @param [String] text The text to truncate
      # @param [Integer] length The maximum length of the text
      # @return [String] The truncated text with ellipsis if shortened
      def truncate_text(text, length)
        return text if text.length <= length

        text[0..length - 4] + '...'
      end
    end
  end
end
