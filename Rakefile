# frozen_string_literal: true

# Rakefile

require 'sequel'
require_relative 'lib/blueprintsCLI/configuration'

# Use BlueprintsCLI configuration system
CONFIG = BlueprintsCLI::Configuration.new

namespace :db do
  desc 'Create the database'
  task :create do
    require 'uri'
    uri = URI.parse(CONFIG.database_url)
    `createdb #{uri.path[1..]}`  # Remove leading slash from path
  end

  desc 'Drop the database'
  task :drop do
    require 'uri'
    uri = URI.parse(CONFIG.database_url)
    `dropdb #{uri.path[1..]}`  # Remove leading slash from path
  end

  desc 'Migrate the database'
  task :migrate do
    Sequel.extension :migration
    db = Sequel.connect(CONFIG.database_url)
    Sequel::Migrator.run(db, 'lib/blueprintsCLI/db/migrate')
  end

  desc 'Seed the database'
  task :seed do
    require_relative 'lib/blueprintsCLI/db/seeds' if File.exist?('lib/blueprintsCLI/db/seeds.rb')
  end
end
