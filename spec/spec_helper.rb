# frozen_string_literal: true

# spec/spec_helper.rb
require 'simplecov'
SimpleCov.start

# Set the environment to "test"
ENV['RACK_ENV'] = 'test'

# Load the application
require_relative '../lib/BlueprintsCLI'
require_relative '../lib/blueprintsCLI/database'

# Load RSpec and Rack::Test
require 'rspec'
require 'rack/test'
require 'factory_bot'

# Configure RSpec
RSpec.configure do |config|
  # Include Rack::Test::Methods for API testing
  config.include Rack::Test::Methods

  # Include FactoryBot syntax methods
  config.include FactoryBot::Syntax::Methods

  # Load factory definitions
  config.before(:suite) do
    FactoryBot.find_definitions
  end

  # Database cleaning strategy
  config.before(:suite) do
    # Run migrations before the test suite starts
    db_instance = BlueprintsCLI::BlueprintDatabase.new
    Sequel.extension :migration
    db_path = File.expand_path('../lib/blueprintsCLI/db/migrate', __dir__)
    Sequel::Migrator.run(db_instance.db, db_path)
  end

  config.around(:each) do |example|
    # Use a database transaction for each test
    db_instance = BlueprintsCLI::BlueprintDatabase.new
    db_instance.db.transaction(rollback: :always, auto_savepoint: true) do
      example.run
    end
  end

  # Expectation framework configuration
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # Mock framework configuration
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # Shared context configuration
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Function to define the app for Rack::Test
  def app
    BlueprintsCLI::WebApp
  end
end
