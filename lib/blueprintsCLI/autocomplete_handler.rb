# frozen_string_literal: true

module BlueprintsCLI
  ##
  # AutocompleteHandler provides intelligent autocomplete suggestions
  # for slash commands, blueprint IDs, file paths, and configuration keys.
  #
  # This class aims to enhance the user experience by providing real-time
  # suggestions as the user types commands and arguments in the CLI.
  # It caches blueprint IDs and configuration keys to improve performance and
  # integrates with `Readline` for a seamless autocomplete experience.
  #
  # @example
  #   handler = BlueprintsCLI::AutocompleteHandler.new
  #   completions = handler.completions_for('/blueprint view 123')
  #   # => ['/blueprint view 1234', '/blueprint view 1235']
  class AutocompleteHandler
    def initialize
      @blueprint_cache = {}
      @config_keys_cache = nil
      @cache_timestamp = nil
      @readline_ready = false
    end

    ##
    # Get completions for the given input.
    #
    # This method is the main entry point for generating autocomplete suggestions.
    # It determines whether the input is a slash command or a general input
    # and calls the appropriate helper methods to generate completions.
    #
    # @param input [String] The input string for which to generate completions.
    # @return [Array<String>] An array of completion suggestions. Returns an empty array if input is nil or empty, or if an error occurs.
    # @example Slash command completion
    #   handler.completions_for('/blueprint view')
    #   # => ['/blueprint view 1234', '/blueprint view 4567']
    # @example General completion
    #   handler.completions_for('se')
    #   # => ['search', 'setup']
    def completions_for(input)
      return [] if input.nil? || input.empty?

      begin
        if input.start_with?('/')
          slash_command_completions(input)
        else
          general_completions(input)
        end
      rescue StandardError => e
        safe_log_debug("Autocomplete error: #{e.message}")
        safe_log_debug("Error backtrace: #{e.backtrace.first(3).join(', ')}")
        []
      end
    end

    ##
    # Mark readline as ready for integration.
    #
    # This method sets the `@readline_ready` flag to true, indicating that
    # the AutocompleteHandler is ready to be integrated with the `Readline` library.
    #
    # @return [void]
    # @example
    #   handler.readline_ready!
    def readline_ready!
      @readline_ready = true
      safe_log_debug('AutocompleteHandler marked as readline ready')
    end

    ##
    # Check if readline integration is active.
    #
    # This method returns the value of the `@readline_ready` flag, indicating
    # whether the AutocompleteHandler is ready to be integrated with the `Readline` library.
    #
    # @return [Boolean] True if readline integration is active, false otherwise.
    # @example
    #   handler.readline_ready?
    #   # => true
    def readline_ready?
      @readline_ready
    end

    ##
    # Reset all caches.
    #
    # This method clears the blueprint cache, config keys cache, and cache timestamp.
    # It is useful for refreshing the autocomplete suggestions when the underlying
    # data has changed.
    #
    # @return [void]
    # @example
    #   handler.reset_cache!
    def reset_cache!
      @blueprint_cache.clear
      @config_keys_cache = nil
      @cache_timestamp = nil
      safe_log_debug('AutocompleteHandler cache reset')
    end

    private

    ##
    # Get completions for slash commands.
    #
    # This method parses the input as a slash command and generates completions
    # based on the command and its arguments. It uses the `SlashCommandParser`
    # to extract the command and subcommands, and then calls the appropriate
    # helper methods to generate completions.
    #
    # @param input [String] The input string for which to generate completions.
    # @return [Array<String>] An array of completion suggestions for the slash command.
    def slash_command_completions(input)
      parser = SlashCommandParser.new(input)

      # Get base command completions from parser
      base_completions = parser.completions
      safe_log_debug("Base completions for '#{input}': #{base_completions.size} items")

      # Enhance with dynamic completions based on context
      enhanced_completions = []

      case parser.command
      when 'blueprint'
        enhanced_completions.concat(blueprint_specific_completions(parser))
      when 'config'
        enhanced_completions.concat(config_specific_completions(parser))
      when 'docs'
        enhanced_completions.concat(docs_specific_completions(parser))
      end

      safe_log_debug("Enhanced completions: #{enhanced_completions.size} items")

      # Combine and deduplicate
      all_completions = (base_completions + enhanced_completions).uniq.sort
      safe_log_debug("Total completions: #{all_completions.size} items")

      all_completions
    end

    ##
    # Get completions for blueprint-specific commands.
    #
    # This method generates completions for the `blueprint` slash command based on
    # the subcommand and its arguments. It calls the appropriate helper methods
    # to generate completions for blueprint IDs, file paths, search terms, and
    # format options.
    #
    # @param parser [SlashCommandParser] The parser object containing the command and subcommand.
    # @return [Array<String>] An array of completion suggestions for the blueprint-specific command.
    def blueprint_specific_completions(parser)
      completions = []

      case parser.subcommand
      when 'view', 'edit', 'delete', 'export'
        # Complete with blueprint IDs
        completions.concat(blueprint_id_completions(parser.input))
      when 'submit'
        # Complete with file paths and interactive option
        completions.concat(file_path_completions(parser.input))
        completions.push('/blueprint submit --interactive')
      when 'search'
        # Complete with previous search terms or popular queries
        completions.concat(search_term_completions(parser.input))
      when 'list'
        # Complete with format options
        completions.push(
          '/blueprint list --format=table',
          '/blueprint list --format=json',
          '/blueprint list --format=summary'
        )
      end

      completions
    end

    ##
    # Get completions for config-specific commands.
    #
    # This method generates completions for the `config` slash command based on
    # the subcommand and its arguments. It calls the appropriate helper methods
    # to generate completions for configuration keys.
    #
    # @param parser [SlashCommandParser] The parser object containing the command and subcommand.
    # @return [Array<String>] An array of completion suggestions for the config-specific command.
    def config_specific_completions(parser)
      completions = []

      case parser.subcommand
      when 'show', 'edit'
        # Complete with configuration keys
        completions.concat(config_key_completions(parser.input))
      end

      completions
    end

    ##
    # Get completions for docs-specific commands.
    #
    # This method generates completions for the `docs` slash command based on
    # the subcommand and its arguments. It calls the appropriate helper methods
    # to generate completions for Ruby file paths.
    #
    # @param parser [SlashCommandParser] The parser object containing the command and subcommand.
    # @return [Array<String>] An array of completion suggestions for the docs-specific command.
    def docs_specific_completions(parser)
      completions = []

      case parser.subcommand
      when 'generate'
        # Complete with Ruby file paths
        completions.concat(ruby_file_completions(parser.input))
      end

      completions
    end

    ##
    # Get completions for blueprint IDs.
    #
    # This method retrieves blueprint IDs from the cache and filters them based on
    # the input prefix. It returns a limited number of matching IDs to avoid
    # overwhelming the user with too many suggestions.
    #
    # @param input [String] The input string for which to generate completions.
    # @return [Array<String>] An array of completion suggestions for blueprint IDs.
    # @example
    #   blueprint_id_completions('/blueprint view 1')
    #   # => ['/blueprint view 1234', '/blueprint view 1235']
    def blueprint_id_completions(input)
      blueprint_ids = cached_blueprint_ids
      prefix = extract_id_prefix(input)

      if prefix.empty?
        blueprint_ids.first(10).map { |id| "#{input.split.first(2).join(' ')} #{id}" }
      else
        matching_ids = blueprint_ids.select { |id| id.to_s.start_with?(prefix) }
        matching_ids.first(5).map { |id| input.gsub(/\d*$/, id.to_s) }
      end
    end

    ##
    # Get completions for file paths.
    #
    # This method generates completions for file paths based on the input.
    # It extracts the partial path from the input and searches for files in the
    # corresponding directory that match the filename prefix.
    #
    # @param input [String] The input string for which to generate completions.
    # @return [Array<String>] An array of completion suggestions for file paths.
    # @example
    #   file_path_completions('/blueprint submit ./my_')
    #   # => ['/blueprint submit ./my_blueprint.rb', '/blueprint submit ./my_other_file.txt']
    def file_path_completions(input)
      # Extract the partial path from the input
      parts = input.split
      return [] if parts.size < 3

      partial_path = parts[2..].join(' ')
      directory = File.dirname(partial_path)
      filename_prefix = File.basename(partial_path)

      begin
        dir_to_scan = directory == '.' ? Dir.pwd : directory
        return [] unless Dir.exist?(dir_to_scan)

        entries = Dir.entries(dir_to_scan)
                     .reject { |entry| entry.start_with?('.') }
                     .select { |entry| entry.start_with?(filename_prefix) }
                     .first(10)

        base_command = parts[0..1].join(' ')
        entries.map do |entry|
          full_path = File.join(directory, entry)
          "#{base_command} #{full_path}"
        end
      rescue StandardError
        []
      end
    end

    ##
    # Get completions for search terms.
    #
    # This method generates completions for search terms based on a list of
    # common terms. It filters the list based on the input prefix and returns
    # a limited number of matching terms.
    #
    # @param input [String] The input string for which to generate completions.
    # @return [Array<String>] An array of completion suggestions for search terms.
    # @example
    #   search_term_completions('/blueprint search rub')
    #   # => ['/blueprint search ruby', '/blueprint search rspec']
    def search_term_completions(input)
      # Enhanced with language-specific terms and popular search terms
      common_terms = %w[
        ruby rails javascript python react node api rest graphql database
        ansible terraform docker kubernetes yaml json class function
        sinatra flask django express fastapi vue angular
        css scss sass html erb haml markdown sql migration
        redis postgresql mongodb elasticsearch nginx apache
        aws azure gcp deployment infrastructure automation
        testing rspec jest mocha cucumber selenium capybara
        gem npm pip composer bundler webpack babel typescript
      ]
      parts = input.split

      return [] if parts.size < 2

      partial_term = parts.last
      base_command = parts[0..-2].join(' ')

      matching_terms = common_terms.select { |term| term.start_with?(partial_term.downcase) }
      matching_terms.first(8).map { |term| "#{base_command} #{term}" }
    end

    ##
    # Get completions for configuration keys.
    #
    # This method retrieves configuration keys from the cache and filters them based on
    # the input prefix. It returns a limited number of matching keys to avoid
    # overwhelming the user with too many suggestions.
    #
    # @param input [String] The input string for which to generate completions.
    # @return [Array<String>] An array of completion suggestions for configuration keys.
    # @example
    #   config_key_completions('/config show log')
    #   # => ['/config show logger.level', '/config show logger.file_logging']
    def config_key_completions(input)
      config_keys = cached_config_keys
      parts = input.split

      return [] if parts.size < 3

      partial_key = parts.last
      base_command = parts[0..-2].join(' ')

      matching_keys = config_keys.select { |key| key.start_with?(partial_key) }
      matching_keys.first(5).map { |key| "#{base_command} #{key}" }
    end

    ##
    # Get completions for Ruby file paths.
    #
    # This method generates completions for Ruby file paths based on the input.
    # It extracts the partial path from the input and searches for Ruby files in the
    # corresponding directory that match the filename prefix.
    #
    # @param input [String] The input string for which to generate completions.
    # @return [Array<String>] An array of completion suggestions for Ruby file paths.
    # @example
    #   ruby_file_completions('/docs generate ./my_')
    #   # => ['/docs generate ./my_class.rb', '/docs generate ./my_module.rb']
    def ruby_file_completions(input)
      parts = input.split
      return [] if parts.size < 3

      partial_path = parts[2..].join(' ')
      directory = File.dirname(partial_path)
      filename_prefix = File.basename(partial_path)

      begin
        dir_to_scan = directory == '.' ? Dir.pwd : directory
        return [] unless Dir.exist?(dir_to_scan)

        ruby_files = Dir.entries(dir_to_scan)
                        .select { |entry| entry.end_with?('.rb') }
                        .select { |entry| entry.start_with?(filename_prefix) }
                        .first(10)

        base_command = parts[0..1].join(' ')
        ruby_files.map do |file|
          full_path = File.join(directory, file)
          "#{base_command} #{full_path}"
        end
      rescue StandardError
        []
      end
    end

    ##
    # Get general completions for non-slash commands.
    #
    # This method provides general suggestions for non-slash commands, such as
    # suggesting slash commands or common actions.
    #
    # @param input [String] The input string for which to generate completions.
    # @return [Array<String>] An array of general completion suggestions.
    # @example
    #   general_completions('/')
    #   # => ['/']
    # @example
    #   general_completions('se')
    #   # => ['search', 'setup']
    def general_completions(input)
      # For non-slash commands, provide general suggestions
      suggestions = []

      # Suggest slash commands if input could be part of one
      suggestions << '/' if input.length == 1 && '/'.start_with?(input)

      # Suggest common actions
      common_actions = %w[search list help config setup]
      matching_actions = common_actions.select { |action| action.start_with?(input.downcase) }
      suggestions.concat(matching_actions)

      suggestions
    end

    ##
    # Get cached blueprint IDs.
    #
    # This method retrieves blueprint IDs from the cache if the cache is valid.
    # If the cache is not valid, it fetches the blueprint IDs from the database,
    # caches them, and returns them.
    #
    # @return [Array<String>] An array of cached blueprint IDs. Returns an empty array if there is an error fetching IDs.
    def cached_blueprint_ids
      return @blueprint_cache[:ids] if cache_valid?

      begin
        # Fetch blueprint IDs from database
        require_relative 'database'
        db = BlueprintsCLI::BlueprintDatabase.new

        blueprints = db.all_blueprints
        ids = blueprints.map { |bp| bp[:id] }.sort

        @blueprint_cache = {
          ids: ids,
          timestamp: Time.now,
          count: blueprints.size
        }

        safe_log_debug("Cached #{ids.size} blueprint IDs")
        ids
      rescue StandardError => e
        safe_log_warn("Failed to fetch blueprint IDs: #{e.message}")
        safe_log_debug("Database error details: #{e.backtrace.first(2).join(', ')}")

        # Return empty array but don't cache the failure
        []
      end
    end

    ##
    # Get cached configuration keys.
    #
    # This method retrieves configuration keys from the cache. If the cache is empty,
    # it initializes the cache with a list of available configuration keys.
    #
    # @return [Array<String>] An array of cached configuration keys.
    def cached_config_keys
      return @config_keys_cache if @config_keys_cache

      # Get available configuration keys
      config_keys = %w[
        logger.level
        logger.file_logging
        logger.file_path
        ai.sublayer.provider
        ai.sublayer.model
        ai.rubyllm.default_model
        database.url
        editor.default
        ui.colors
        features.auto_description
        features.auto_categorize
      ]

      @config_keys_cache = config_keys
      config_keys
    end

    ##
    # Check if the blueprint cache is valid.
    #
    # The cache is considered valid if it has a timestamp and the timestamp is
    # less than 60 seconds old.
    #
    # @return [Boolean] True if the cache is valid, false otherwise.
    def cache_valid?
      @blueprint_cache[:timestamp] &&
        (Time.now - @blueprint_cache[:timestamp]) < 60 # Cache for 60 seconds
    end

    ##
    # Extract the ID prefix from the input.
    #
    # This method extracts the partial ID from the end of the input.
    # It assumes that the ID is the last part of the input and starts with a digit.
    #
    # @param input [String] The input string from which to extract the ID prefix.
    # @return [String] The ID prefix, or an empty string if no ID prefix is found.
    # @example
    #   extract_id_prefix('/blueprint view 12')
    #   # => '12'
    # @example
    #   extract_id_prefix('/blueprint view abc')
    #   # => ''
    def extract_id_prefix(input)
      # Extract the partial ID from the end of the input
      parts = input.split
      return '' if parts.size < 3

      last_part = parts.last
      last_part.match?(/^\d/) ? last_part : ''
    end

    ##
    # Safe logging method for debugging messages.
    #
    # This method logs a debug message using the `BlueprintsCLI.logger` if it is available.
    # If the logger is not available, it silently ignores the error.
    #
    # @param message [String] The message to log.
    # @return [void]
    def safe_log_debug(message)
      if defined?(BlueprintsCLI) && BlueprintsCLI.respond_to?(:logger)
        BlueprintsCLI.logger.debug(message)
      end
    rescue StandardError
      # Silently ignore logging errors during initialization
    end

    ##
    # Safe logging method for warning messages.
    #
    # This method logs a warning message using the `BlueprintsCLI.logger` if it is available.
    # If the logger is not available, it silently ignores the error.
    #
    # @param message [String] The message to log.
    # @return [void]
    def safe_log_warn(message)
      if defined?(BlueprintsCLI) && BlueprintsCLI.respond_to?(:logger)
        BlueprintsCLI.logger.warn(message)
      end
    rescue StandardError
      # Silently ignore logging errors during initialization
    end
  end
end
