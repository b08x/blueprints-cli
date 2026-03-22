# frozen_string_literal: true

require "tty-box"

module BlueprintsCLI
  module Actions
    # Search provides search functionality for blueprints in the system.
    # Supports both semantic vector-based search and traditional text search.
    #
    # @example Basic semantic search
    #   action = Search.new(query: "user authentication")
    #   action.call
    #
    # @example Text search with custom limit
    #   action = Search.new(query: "database connection", semantic: false, limit: 5)
    #   action.call
    #
    # @example Injected database for testing
    #   action = Search.new(query: "auth", db: FakeBlueprintDatabase.new)
    #   action.call
    class Search
      # Maximum records fetched for in-memory text filtering.
      # TODO: Replace with a DB-side pg_trgm / ILIKE scope for O(log n) at scale.
      TEXT_SEARCH_FETCH_LIMIT = 200

      # @param query [String] The search term to look for in blueprints
      # @param limit [Integer] Maximum number of results to return (default: 10)
      # @param semantic [Boolean] Whether to use semantic search (default: true)
      # @param db [#search_blueprints, #list_blueprints] Injectable database dependency
      def initialize(query:, limit: 10, semantic: true, db: BlueprintsCLI::BlueprintDatabase.new)
        @query = query
        @limit = limit
        @semantic = semantic
        @db = db
      end

      # Executes the blueprint search based on the configured parameters.
      #
      # @return [Boolean] true if search completed successfully, false on error
      def call
        BlueprintsCLI.logger.info("Searching for: '#{@query}'")

        results = @semantic ? semantic_search : text_search

        if results.empty?
          BlueprintsCLI.logger.info("No blueprints found matching '#{@query}'")
          return true
        end

        BlueprintsCLI.logger.info("Found #{results.length} matching blueprints")
        display_search_results(results)
        true
      rescue => e
        BlueprintsCLI.logger.failure("Error searching blueprints: #{e.message}")
        BlueprintsCLI.logger.debug(e.backtrace.first) if ENV["DEBUG"]
        false
      end

      private def semantic_search
        @db.search_blueprints(query: @query, limit: @limit)
      end

      # Performs a traditional text-based search across blueprint fields.
      # Searches query terms across name, description, code, and categories.
      #
      # @return [Array<Hash>] Matching blueprint hashes, scored and ranked
      private def text_search
        blueprints = @db.list_blueprints(limit: TEXT_SEARCH_FETCH_LIMIT)
        query_words = @query.downcase.split(/\s+/)

        blueprints
          .select { |bp| matches_all_words?(bp, query_words) }
          .sort_by { |bp| -calculate_text_relevance(bp, query_words) }
          .first(@limit)
      end

      # @param blueprint [Hash]
      # @param query_words [Array<String>]
      # @return [Boolean]
      private def matches_all_words?(blueprint, query_words)
        text = searchable_text(blueprint)
        query_words.all? { |word| text.include?(word) }
      end

      # Builds a single downcased string from all searchable blueprint fields.
      #
      # @param blueprint [Hash]
      # @return [String]
      private def searchable_text(blueprint)
        [
          blueprint[:name],
          blueprint[:description],
          blueprint[:code],
          blueprint[:categories]&.map { |c| c[:title] }&.join(" "),
        ].compact.join(" ").downcase
      end

      # Calculates a weighted relevance score for a blueprint.
      # Weights: name=10pts, description=5pts, code=1pt per matching word.
      #
      # @param blueprint [Hash]
      # @param query_words [Array<String>]
      # @return [Integer]
      private def calculate_text_relevance(blueprint, query_words)
        name_text = (blueprint[:name] || "").downcase
        desc_text = (blueprint[:description] || "").downcase
        code_text = (blueprint[:code] || "").downcase # nil-safe: was blueprint[:code].downcase

        query_words.sum do |word|
          (name_text.include?(word) ? 10 : 0) +
            (desc_text.include?(word) ? 5 : 0) +
            (code_text.include?(word) ? 1 : 0)
        end
      end

      # Displays the search results in a formatted table.
      # TODO: Extract to a dedicated SearchResultFormatter for testability.
      #
      # @param results [Array<Hash>]
      private def display_search_results(results)
        header_box = TTY::Box.frame(
          "🔍 Search Results for: '#{@query}'",
          width: 120,
          align: :center,
          style: { border: { fg: :blue } }
        )
        puts "\n#{header_box}"

        if @semantic && results.first&.key?(:distance)
          display_semantic_results(results)
        else
          display_text_results(results)
        end

        puts "=" * 120
        puts ""
        show_usage_hints(results)
      end

      # @param results [Array<Hash>] Semantic search results with :distance key
      private def display_semantic_results(results)
        printf "%-5s %-30s %-40s %-20s %-10s\n", "ID", "Name", "Description", "Categories", "Score"
        puts "-" * 120

        results.each do |bp|
          printf "%-5s %-30s %-40s %-20s %-10s\n",
            bp[:id],
            truncate_text(bp[:name] || "Untitled", 28),
            truncate_text(bp[:description] || "No description", 38),
            get_category_text(bp[:categories]),
            "#{calculate_similarity_percentage(bp[:distance])}%"
        end
      end

      # @param results [Array<Hash>] Text search results
      private def display_text_results(results)
        printf "%-5s %-35s %-50s %-25s\n", "ID", "Name", "Description", "Categories"
        puts "-" * 120

        results.each do |bp|
          printf "%-5s %-35s %-50s %-25s\n",
            bp[:id],
            truncate_text(bp[:name] || "Untitled", 33),
            truncate_text(bp[:description] || "No description", 48),
            get_category_text(bp[:categories])
        end
      end

      # Converts vector distance to a similarity percentage (lower distance = more similar).
      #
      # @param distance [Float]
      # @return [Float] Percentage in range 0–100
      private def calculate_similarity_percentage(distance)
        [100 - (distance * 100), 0].max.round(1)
      end

      # @param categories [Array<Hash>, nil]
      # @return [String]
      private def get_category_text(categories)
        return "None" if categories.nil? || categories.empty?

        truncate_text(categories.map { |cat| cat[:title] }.join(", "), 23)
      end

      # @param results [Array<Hash>]
      private def show_usage_hints(results)
        puts "💡 Next steps:".colorize(:cyan)
        puts "   blueprint view <id>           View full blueprint details"
        puts "   blueprint view <id> --analyze Get AI analysis and suggestions"
        puts "   blueprint edit <id>           Edit a blueprint"
        puts "   blueprint export <id>         Export blueprint code"
        puts "\n📋 Example: blueprint view #{results.first[:id]}".colorize(:yellow) if results.any?
        puts ""
      end

      # @param text [String]
      # @param length [Integer]
      # @return [String]
      private def truncate_text(text, length)
        return text if text.length <= length

        "#{text[0..(length - 4)]}..."
      end
    end
  end
end
