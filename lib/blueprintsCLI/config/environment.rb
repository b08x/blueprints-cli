# frozen_string_literal: true

# config/environment.rb

require 'bundler/setup'
Bundler.require

# Set up database connection using environment variables with fallback
ENV['RACK_ENV'] ||= 'development'
require_relative '../configuration'
config = BlueprintsCLI::Configuration.new
DB = Sequel.connect(config.database_url)

# Load initializers
require_relative 'initializers/sublayer'
