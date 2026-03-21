# frozen_string_literal: true

require_relative "../schemas/generator_schemas"
require 'dry/monads'
require 'json'

module BlueprintsCLI
  module Generators
    # Generates a list of relevant categories/tags for a given code blueprint.
    #
    # Uses RubyLLM with a structured output schema guaranteeing an array of
    # strings response — replacing `llm_output_adapter type: :list_of_strings`.
    #
    # @example
    #   generator = BlueprintsCLI::Generators::Category.new(code: code_snippet)
    #   result = generator.generate
    #   # => Success(["ruby", "cli-tool", "configuration"])
    class Category
      include Dry::Monads[:result]

      # @param code [String] The source code to categorise.
      # @param description [String, nil] Optional description for additional context.
      def initialize(code:, description: nil)
        @code        = code
        @description = description
      end

      # Calls the LLM and returns an array of category tag strings.
      #
      # @return [Dry::Monads::Result] Success(categories_array) or Failure(reason)
      def generate
        BlueprintsCLI.configuration.configure_rubyllm!
        response = RubyLLM.chat(model: model_name)
                          .with_schema(Schemas::CategorySchema)
                          .ask(prompt)

        # Handle different response formats from various models
        categories = extract_categories_from_response(response)
        Success(Array(categories))
      rescue RubyLLM::Error => e
        BlueprintsCLI.logger.failure("Category generation failed: #{e.message}")
        Failure(e)
      rescue StandardError => e
        BlueprintsCLI.logger.failure("Unexpected error in category generation: #{e.message}")
        Failure(e)
      end

      private

      # Extract categories from response, handling different model response formats
      def extract_categories_from_response(response)
        # First try standard content format
        if response.content && response.content.is_a?(Hash) && response.content["categories"]
          return response.content["categories"]
        end

        # Try reasoning format (GLM models)
        if response.respond_to?(:thinking) && response.thinking&.text
          begin
            parsed = JSON.parse(response.thinking.text)
            return parsed["categories"] if parsed["categories"]
          rescue JSON::ParserError
            # Fall back to content if JSON parsing fails
          end
        end

        # Fallback: try to extract from raw response
        if response.respond_to?(:raw) && response.raw.respond_to?(:body)
          body = response.raw.body
          if body.is_a?(Hash) && body.dig("choices", 0, "message", "reasoning")
            begin
              reasoning_text = body.dig("choices", 0, "message", "reasoning")
              parsed = JSON.parse(reasoning_text)
              return parsed["categories"] if parsed["categories"]
            rescue JSON::ParserError
              # Continue to fallback
            end
          end
        end

        # Ultimate fallback
        ["ruby", "code-blueprint"]
      end

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
