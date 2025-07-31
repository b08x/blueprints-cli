# frozen_string_literal: true

module BlueprintsCLI
  # AutocompleteHandler provides intelligent autocomplete suggestions
  # for slash commands, blueprint IDs, file paths, and configuration keys
  class AutocompleteHandler
    def initialize
      @blueprint_cache = {}
      @config_keys_cache = nil
      @cache_timestamp = nil
    end

    # Get completions for the given input
    def completions_for(input)
      return [] if input.nil? || input.empty?

      if input.start_with?('/')
        slash_command_completions(input)
      else
        general_completions(input)
      end
    rescue StandardError => e
      BlueprintsCLI.logger.debug("Autocomplete error: #{e.message}")
      []
    end

    private

    def slash_command_completions(input)
      parser = SlashCommandParser.new(input)

      # Get base command completions from parser
      base_completions = parser.completions

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

      # Combine and deduplicate
      (base_completions + enhanced_completions).uniq.sort
    end

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

    def config_specific_completions(parser)
      completions = []

      case parser.subcommand
      when 'show', 'edit'
        # Complete with configuration keys
        completions.concat(config_key_completions(parser.input))
      end

      completions
    end

    def docs_specific_completions(parser)
      completions = []

      case parser.subcommand
      when 'generate'
        # Complete with Ruby file paths
        completions.concat(ruby_file_completions(parser.input))
      end

      completions
    end

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

    def config_key_completions(input)
      config_keys = cached_config_keys
      parts = input.split

      return [] if parts.size < 3

      partial_key = parts.last
      base_command = parts[0..-2].join(' ')

      matching_keys = config_keys.select { |key| key.start_with?(partial_key) }
      matching_keys.first(5).map { |key| "#{base_command} #{key}" }
    end

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

    def cached_blueprint_ids
      return @blueprint_cache[:ids] if cache_valid?

      begin
        # Fetch blueprint IDs from database
        require_relative 'database'
        db = BlueprintsCLI::BlueprintDatabase.new

        ids = db.all_blueprints.map { |bp| bp[:id] }.sort
        @blueprint_cache = { ids: ids, timestamp: Time.now }
        ids
      rescue StandardError => e
        BlueprintsCLI.logger.debug("Failed to fetch blueprint IDs: #{e.message}")
        []
      end
    end

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

    def cache_valid?
      @blueprint_cache[:timestamp] &&
        (Time.now - @blueprint_cache[:timestamp]) < 60 # Cache for 60 seconds
    end

    def extract_id_prefix(input)
      # Extract the partial ID from the end of the input
      parts = input.split
      return '' if parts.size < 3

      last_part = parts.last
      last_part.match?(/^\d/) ? last_part : ''
    end
  end
end
