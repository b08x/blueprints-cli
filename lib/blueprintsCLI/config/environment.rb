# frozen_string_literal: true

# config/environment.rb

require 'bundler/setup'
Bundler.require

# Load main module first
require_relative '../../BlueprintsCLI'

# Set up database connection using unified configuration
ENV['RACK_ENV'] ||= 'development'
DB = Sequel.connect(BlueprintsCLI.configuration.database_url)

# Load initializers
require_relative 'initializers/ruby_llm'
