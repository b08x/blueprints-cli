# frozen_string_literal: true

require 'sequel'
require 'pgvector'

# Represents a single code blueprint in the database.
# This model includes logic for timestamping, associations, and vector-based search.
# Supports multiple programming languages and file types for diverse blueprint management.
class Blueprint < Sequel::Model
  # Use the timestamps plugin to automatically manage created_at and updated_at fields.
  plugin :timestamps, update_on_create: true

  # Set up the many-to-many relationship with the Category model.
  # The join table is implicitly assumed to be :blueprints_categories.
  many_to_many :categories

  # Language detection mapping based on file extensions
  LANGUAGE_MAPPING = {
    '.rb' => 'ruby',
    '.py' => 'python',
    '.js' => 'javascript',
    '.jsx' => 'javascript',
    '.ts' => 'typescript',
    '.tsx' => 'typescript',
    '.java' => 'java',
    '.cpp' => 'cpp',
    '.c' => 'c',
    '.cs' => 'csharp',
    '.php' => 'php',
    '.go' => 'go',
    '.rs' => 'rust',
    '.swift' => 'swift',
    '.kt' => 'kotlin',
    '.scala' => 'scala',
    '.clj' => 'clojure',
    '.hs' => 'haskell',
    '.elm' => 'elm',
    '.yml' => 'yaml',
    '.yaml' => 'yaml',
    '.json' => 'json',
    '.xml' => 'xml',
    '.html' => 'html',
    '.css' => 'css',
    '.scss' => 'scss',
    '.sass' => 'sass',
    '.less' => 'less',
    '.sh' => 'bash',
    '.ps1' => 'powershell',
    '.sql' => 'sql',
    '.dockerfile' => 'dockerfile',
    '.tf' => 'terraform',
    '.vue' => 'vue',
    '.svelte' => 'svelte'
  }.freeze

  # Parser type mapping for different blueprint categories
  PARSER_MAPPING = {
    'ruby' => 'ruby',
    'python' => 'python',
    'javascript' => 'javascript',
    'typescript' => 'javascript',
    'yaml' => 'ansible',
    'json' => 'json',
    'dockerfile' => 'docker',
    'terraform' => 'terraform',
    'vue' => 'vue',
    'svelte' => 'svelte'
  }.freeze

  # Blueprint type classification
  BLUEPRINT_TYPES = {
    'code' => %w[ruby python javascript typescript java cpp c csharp php
      go rust swift kotlin scala clojure haskell elm],
    'configuration' => %w[yaml json xml],
    'template' => %w[html css scss sass less],
    'script' => %w[bash powershell],
    'infrastructure' => %w[dockerfile terraform],
    'database' => ['sql'],
    'frontend' => %w[vue svelte]
  }.freeze

  # Automatically detect and set language, file_type, blueprint_type, and parser_type
  # based on the provided filename or content analysis
  #
  # @param filename [String, nil] The filename to analyze for type detection
  # @return [Hash] Hash containing detected types
  def self.detect_types(filename = nil)
    if filename
      ext = File.extname(filename.downcase)
      language = LANGUAGE_MAPPING[ext] || 'text'
      file_type = ext.empty? ? '.txt' : ext
    else
      language = 'text'
      file_type = '.txt'
    end

    blueprint_type = BLUEPRINT_TYPES.find do |_type, langs|
      langs.include?(language)
    end&.first || 'other'
    parser_type = PARSER_MAPPING[language] || language

    {
      language: language,
      file_type: file_type,
      blueprint_type: blueprint_type,
      parser_type: parser_type
    }
  end

  # Filter blueprints by language
  #
  # @param language [String] The programming language to filter by
  # @return [Sequel::Dataset] Filtered dataset
  def self.by_language(language)
    where(language: language)
  end

  # Filter blueprints by blueprint type
  #
  # @param type [String] The blueprint type to filter by
  # @return [Sequel::Dataset] Filtered dataset
  def self.by_type(type)
    where(blueprint_type: type)
  end

  # Filter blueprints by parser type
  #
  # @param parser [String] The parser type to filter by
  # @return [Sequel::Dataset] Filtered dataset
  def self.by_parser(parser)
    where(parser_type: parser)
  end

  # Get supported languages
  #
  # @return [Array<String>] Array of supported programming languages
  def self.supported_languages
    LANGUAGE_MAPPING.values.uniq.sort
  end

  # Get supported blueprint types
  #
  # @return [Array<String>] Array of supported blueprint types
  def self.supported_blueprint_types
    BLUEPRINT_TYPES.keys.sort
  end

  # Performs a search for blueprints.
  # If a query is provided, it performs a semantic vector search.
  # Otherwise, it returns the most recently created blueprints.
  #
  # @param query [String, nil] The search term.
  # @return [Sequel::Dataset] A dataset of blueprints.
  def self.search(query)
    if query && !query.strip.empty?
      begin
        # Generate an embedding for the search query.
        embedding_result = RubyLLM.embed(query)
        embedding_vector = embedding_result.vectors

        # Use the pgvector cosine distance operator (<->) to find the nearest neighbors.
        # The results are ordered by their distance to the query embedding (lower is better).
        order(Sequel.lit('embedding <-> ?', Pgvector.encode(embedding_vector))).limit(20)
      rescue RubyLLM::Error => e
        # Fall back to text search if embedding fails
        puts "Warning: Search embedding failed: #{e.message}"
        where(Sequel.ilike(:name, "%#{query}%") | Sequel.ilike(:description, "%#{query}%"))
          .order(Sequel.desc(:created_at)).limit(20)
      rescue StandardError => e
        puts "Warning: Search failed: #{e.message}"
        where(Sequel.ilike(:name, "%#{query}%") | Sequel.ilike(:description, "%#{query}%"))
          .order(Sequel.desc(:created_at)).limit(20)
      end
    else
      # If no query is provided, return the 20 most recent blueprints.
      order(Sequel.desc(:created_at)).limit(20)
    end
  end
end
