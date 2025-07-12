# frozen_string_literal: true

# Rakefile

require 'sequel'
require 'yaml'

DB_CONFIG = YAML.load_file('config/database.yml')

namespace :db do
  desc 'Create the database'
  task :create do
    `createdb #{DB_CONFIG['development']['database']}`
  end

  desc 'Drop the database'
  task :drop do
    `dropdb #{DB_CONFIG['development']['database']}`
  end

  desc 'Migrate the database'
  task :migrate do
    Sequel.extension :migration
    db = Sequel.connect(DB_CONFIG['development'])
    Sequel::Migrator.run(db, 'db/migrate')
  end

  desc 'Seed the database'
  task :seed do
    require_relative 'db/seeds'
  end
end
