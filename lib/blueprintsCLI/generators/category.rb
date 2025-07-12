# frozen_string_literal: true

module BlueprintsCLI
  module Generators
    # Generates a list of relevant categories for a given code blueprint by using an LLM.
    #
    # This class is designed to analyze a piece of source code and an optional description,
    # then produce a set of tags that help in organizing and discovering the code blueprint
    # within a larger system. It uses a predefined list of categories to ensure consistency.
    #
    # @example Generating categories for a Ruby script
    #   code_snippet = "class MyScript\n  def run\n    puts 'Hello'\n  end\nend"
    #   description = "A simple hello world script."
    #   generator = BlueprintsCLI::Generators::Category.new(code: code_snippet, description: description)
    #   categories = generator.generate
    #   # => ["ruby", "script", "utility"]
    class Category < Sublayer::Generators::Base
      # Configures the LLM output to be a list of strings named "categories".
      llm_output_adapter type: :list_of_strings,
                         name: 'categories',
                         description: 'Relevant categories and tags for this code blueprint'

      # Initializes a new Category instance.
      #
      # @param code [String] The source code to be analyzed.
      # @param description [String, nil] An optional high-level description of the code
      #   to provide additional context to the LLM.
      def initialize(code:, description: nil)
        @code = code
        @description = description
      end

      # Triggers the LLM to generate categories for the provided code.
      #
      # This method delegates to the parent class's generation logic, which uses the
      # `#prompt` method to build a query for the LLM and parses the response
      # into an array of strings as configured by the `llm_output_adapter`.
      #
      # @return [Array<String>] A list of 2-4 category tags for the code.
      def generate
        super
      end

      # Builds the prompt string for the LLM.
      #
      # This method constructs a detailed prompt that includes the code, its description,
      # and a predefined list of categories to guide the LLM in its analysis. The goal
      # is to get a consistent and relevant set of tags.
      #
      # @return [String] The complete prompt to be sent to the LLM.
      def prompt
        content_to_analyze = [@description, @code].compact.join("\n\n")

        <<-PROMPT
          Analyze this code and generate relevant categories/tags for organization and discovery.

          #{@description ? "Description: #{@description}" : ''}

          Code:
          ```
          #{@code}
          ```

          Please categorize this code with 2-4 relevant tags from the following categories:

          **Programming Languages & Frameworks:**
          ruby, python, javascript, rails, react, vue, express, flask, django

          **Application Types:**
          web-app, api, cli-tool, library, script, microservice, database-migration

          **Domain Areas:**
          authentication, authorization, data-processing, file-handling, web-scraping,#{' '}
          text-processing, image-processing, email, notifications, logging, monitoring

          **Patterns & Concepts:**
          mvc, rest-api, graphql, async, background-jobs, caching, testing, validation,
          error-handling, configuration, security, performance-optimization

          **Technical Areas:**
          database, orm, sql, nosql, redis, elasticsearch, docker, kubernetes,#{' '}
          json, xml, csv, pdf, encryption, oauth, jwt

          **Utility Types:**
          utility, helper, wrapper, adapter, parser, formatter, converter, generator

          Return only the most relevant 2-4 categories that best describe this code.
          Choose existing categories when possible rather than creating new ones.
        PROMPT
      end
    end
  end
end
