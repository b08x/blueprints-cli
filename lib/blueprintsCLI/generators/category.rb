# frozen_string_literal: true

require_relative "../schemas/generator_schemas"

module BlueprintsCLI
  module Generators
    # Generates a list of relevant categories/tags for a given code blueprint.
    #
    # Uses RubyLLM with a structured output schema guaranteeing an array of
    # strings response — replacing `llm_output_adapter type: :list_of_strings`.
    #
    # @example
    #   generator = BlueprintsCLI::Generators::Category.new(code: code_snippet)
    #   categories = generator.generate
    #   # => ["ruby", "cli-tool", "configuration"]
    class Category
      # @param code [String] The source code to categorise.
      # @param description [String, nil] Optional description for additional context.
      def initialize(code:, description: nil)
        @code        = code
        @description = description
      end

      # Calls the LLM and returns an array of category tag strings.
      #
      # @return [Array<String>] 2-4 category tags for the blueprint.
      def generate
        response = RubyLLM.chat(model: model_name)
                          .with_schema(Schemas::CategorySchema)
                          .ask(prompt)
        Array(response.content["categories"])
      rescue RubyLLM::Error => e
        BlueprintsCLI.logger.failure("Category generation failed: #{e.message}")
        []
      end

      private

      def model_name
        BlueprintsCLI.configuration.fetch(:ai, :rubyllm, :default_model,
                                          default: "gemini-2.0-flash")
      end

      def prompt
        <<~PROMPT
          Analyze this code and generate relevant categories/tags for organization and discovery.

          #{@description ? "Description: #{@description}" : ""}

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
          authentication, authorization, data-processing, file-handling, web-scraping,
          text-processing, image-processing, email, notifications, logging, monitoring

          **Patterns & Concepts:**
          mvc, rest-api, graphql, async, background-jobs, caching, testing, validation,
          error-handling, configuration, security, performance-optimization

          **Technical Areas:**
          database, orm, sql, nosql, redis, elasticsearch, docker, kubernetes,
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
