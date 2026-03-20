# frozen_string_literal: true

# config/environment.rb

require 'bundler/setup'
Bundler.require

# Set up database connection using environment variables with fallback
ENV['RACK_ENV'] ||= 'development'
require_relative '../configuration'
DB = Sequel.connect(BlueprintsCLI.configuration.database_url)

# Load initializers
require_relative 'initializers/ruby_llm'
