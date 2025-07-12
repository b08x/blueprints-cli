# frozen_string_literal: true

# config/environment.rb

require 'bundler/setup'
Bundler.require

# Set up database connection
require 'yaml'
ENV['RACK_ENV'] ||= 'development'
DB_CONFIG = YAML.load_file(File.join(File.dirname(__FILE__), 'database.yml'))
DB = Sequel.connect(DB_CONFIG[ENV['RACK_ENV']])

# Load initializers
require_relative 'initializers/sublayer'
