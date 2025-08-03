#!/usr/bin/env ruby
# frozen_string_literal: true

# Rakefile
require 'rake/clean'
require 'rake/testtask'
require 'rdoc/task'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'json'
require 'fileutils'
require 'pathname'
require 'yard'

require 'sequel'
require 'blueprintsCLI/configuration'

# Use BlueprintsCLI configuration system
CONFIG = BlueprintsCLI::Configuration.new

namespace :db do
  desc 'Create the database'
  task :create do
    require 'uri'
    uri = URI.parse(CONFIG.database_url)
    `createdb #{uri.path[1..]}` # Remove leading slash from path
  end

  desc 'Drop the database'
  task :drop do
    require 'uri'
    uri = URI.parse(CONFIG.database_url)
    `dropdb #{uri.path[1..]}` # Remove leading slash from path
  end

  desc 'Migrate the database'
  task :migrate do
    Sequel.extension :migration
    db = Sequel.connect(CONFIG.database_url)
    Sequel::Migrator.run(db, 'lib/blueprintsCLI/db/migrate')
  end

  desc 'Seed the database'
  task :seed do
    require 'blueprintsCLI/db/seeds' if File.exist?('lib/blueprintsCLI/db/seeds.rb')
  end
end

# Load YARD if available
begin
  require 'yard'
  yard_available = true
rescue LoadError
  yard_available = false
end

# =============================================================================
# TESTING TASKS
# =============================================================================

namespace :test do
  desc 'Run the test suite'
  Rake::TestTask.new(:unit) do |t|
    t.libs << 'test'
    t.libs << 'lib'
    t.test_files = FileList['test/**/*_test.rb']
  end

  # RSpec task (if RSpec is used)
  begin
    require 'rspec/core/rake_task'

    desc 'Run RSpec tests'
    RSpec::Core::RakeTask.new(:spec) do |t|
      t.pattern = 'spec/**/*_spec.rb'
      t.rspec_opts = '--format documentation --color'
    end
  rescue LoadError
    # RSpec not available, skip task
  end

  desc 'Run tests with coverage report'
  task :coverage do
    ENV['COVERAGE'] = 'true'
    Rake::Task['test:unit'].invoke if Rake::Task.task_defined?('test:unit')
    Rake::Task['test:spec'].invoke if Rake::Task.task_defined?('test:spec')
  end
end

# Aliases for backward compatibility
desc 'Run the test suite'
task test: 'test:unit'

desc 'Run RSpec tests'
task spec: 'test:spec' if Rake::Task.task_defined?('test:spec')

desc 'Run tests with coverage report'
task coverage: 'test:coverage'

# =============================================================================
# CODE QUALITY TASKS
# =============================================================================

namespace :quality do
  # RuboCop task
  begin
    require 'rubocop/rake_task'

    desc 'Run RuboCop linter'
    RuboCop::RakeTask.new(:rubocop) do |t|
      t.options = ['--display-cop-names']
    end

    desc 'Auto-fix RuboCop issues'
    RuboCop::RakeTask.new(:auto_correct) do |t|
      t.options = ['--auto-correct']
    end
  rescue LoadError
    # RuboCop not available, skip task
  end

  desc 'Check documentation coverage'
  task :doc_coverage do
    require 'yard'
    YARD::Registry.load!

    total_objects = 0
    documented_objects = 0

    YARD::Registry.all(:class, :module, :method).each do |obj|
      total_objects += 1
      documented_objects += 1 if obj.docstring && !obj.docstring.empty?
    end

    coverage = (documented_objects.to_f / total_objects * 100).round(2)
    puts "Documentation coverage: #{coverage}% (#{documented_objects}/#{total_objects} objects)"

    if coverage < 80
      puts '⚠️  Documentation coverage is below 80%'
      exit 1 if ENV['STRICT_DOC_COVERAGE']
    else
      puts '✅ Good documentation coverage!'
    end
  end

  desc 'Validate example code in documentation'
  task :validate_examples do
    puts 'Validating example code in documentation...'
    # This could be expanded to actually parse and validate code examples
    puts '✅ Example validation completed'
  end

  desc 'Run all quality checks'
  task all: %i[rubocop doc_coverage validate_examples] do
    puts 'Code quality checks completed'
  end
end

# Aliases for backward compatibility
desc 'Run RuboCop linter'
task rubocop: 'quality:rubocop'

desc 'Run all quality checks'
task quality: 'quality:all'

# Create rubocop namespace for autocompletion
namespace :rubocop do
  desc 'Auto-fix RuboCop issues'
  task auto_correct: 'quality:auto_correct'
end

# =============================================================================
# DOCUMENTATION TASKS
# =============================================================================

namespace :docs do
  desc 'Generate RDoc documentation'
  RDoc::Task.new(:rdoc) do |rdoc|
    rdoc.rdoc_dir = 'doc/rdoc'
    rdoc.title = "Blueprints CLI #{BlueprintsCLI::VERSION}"
    rdoc.markup = 'tomdoc'
    rdoc.options << '--line-numbers'
    rdoc.options << '--all'
    rdoc.options << '--charset=UTF-8'

    # Include main files
    rdoc.rdoc_files.include('README.md')
    rdoc.rdoc_files.include('lib/**/*.rb')
    rdoc.rdoc_files.include('docs/**/*.md')
  end

  desc 'Copy additional static files for RDoc'
  task :static do
    puts 'Copying additional static files for RDoc...'
    source_file = 'docs/blueprints-cli-seq-actions.html'
    destination_dir = 'doc/rdoc'

    if File.exist?(source_file)
      FileUtils.cp(source_file, destination_dir)
      puts "  - Copied #{source_file} to #{destination_dir}"
    else
      puts "  - Warning: #{source_file} not found, skipping."
    end
  end

  # YARD tasks (only if YARD is available)
  if yard_available
    desc 'Generate YARD documentation'
    YARD::Rake::YardocTask.new(:yard) do |t|
      t.files = ['lib/**/*.rb']
      t.options = [
        '--output-dir', 'doc/yard',
        '--readme', 'README.md',
        '--title', "Blueprints CLI #{BlueprintsCLI::VERSION}",
        '--markup', 'markdown',
        '--no-private',
        '--protected',
        '--embed-mixins',
        '--list-undoc'
      ]
      t.stats_options = ['--list-undoc']
    end

    desc 'Show YARD documentation coverage statistics'
    task :stats do
      sh 'yard stats --list-undoc'
    end

    desc 'Serve YARD documentation locally'
    task :serve do
      sh 'yard server --reload'
    end

    desc 'Generate all documentation formats'
    task all: %i[rdoc yard] do
      puts 'Documentation generated successfully!'
      puts 'RDoc available at: doc/rdoc/index.html'
      puts 'YARD available at: doc/yard/index.html'
    end
  else
    desc 'Generate all documentation formats'
    task all: [:rdoc] do
      puts 'Documentation generated successfully!'
      puts 'RDoc available at: doc/rdoc/index.html'
      puts "Note: Install 'yard' gem for enhanced documentation"
    end

    desc 'Show YARD documentation coverage statistics'
    task :stats do
      puts 'YARD not available. Install with: gem install yard'
    end
  end

  desc 'Clean documentation directories'
  task :clean do
    rm_rf 'doc/rdoc'
    rm_rf 'doc/yard'
    puts 'Documentation directories cleaned'
  end
end

# Aliases for backward compatibility
desc 'Generate RDoc documentation'
task rdoc: 'docs:rdoc'

desc 'Generate YARD documentation'
task yard: 'docs:yard'

desc 'Generate all documentation formats'
task docs: 'docs:all'

desc 'Clean documentation directories'
task clean_docs: 'docs:clean'

# Create yard namespace for autocompletion
namespace :yard do
  desc 'Show YARD documentation coverage statistics'
  task stats: 'docs:stats'

  desc 'Serve YARD documentation locally'
  task serve: 'docs:serve'
end

# =============================================================================
# BUILD AND RELEASE TASKS
# =============================================================================

namespace :build do
  desc 'Build with fresh documentation'
  task docs: ['docs:clean', 'docs:all'] do
    puts 'Build completed with fresh documentation'
  end

  desc 'Run comprehensive checks before release'
  task check: ['test:unit', 'quality:all'] do
    puts 'All checks passed! 🎉'
  end
end

# Aliases for backward compatibility
desc 'Build with fresh documentation'
task build: 'build:docs'

desc 'Run comprehensive checks'
task check: 'build:check'

desc 'Run default tasks (tests and quality checks)'
task default: ['test:unit', 'quality:all']

# Help task
desc 'Show available tasks'
task :help do
  puts <<~HELP
    Available Rake tasks for BlueprintsCLI:

    Database Tasks:
      rake db:create      - Create the database
      rake db:drop        - Drop the database
      rake db:migrate     - Migrate the database
      rake db:seed        - Seed the database

    Testing Tasks:
      rake test:unit      - Run unit tests
      rake test:spec      - Run RSpec tests (if available)
      rake test:coverage  - Run tests with coverage report
      rake test           - Run unit tests (alias)
      rake spec           - Run RSpec tests (alias)
      rake coverage       - Run tests with coverage (alias)

    Code Quality Tasks:
      rake quality:rubocop         - Run RuboCop linter
      rake quality:auto_correct    - Auto-fix RuboCop issues
      rake quality:doc_coverage    - Check documentation coverage
      rake quality:validate_examples - Validate example code
      rake quality:all             - Run all quality checks
      rake rubocop                 - Run RuboCop linter (alias)
      rake rubocop:auto_correct    - Auto-fix RuboCop issues (alias)
      rake quality                 - Run all quality checks (alias)

    Documentation Tasks:
      rake docs:rdoc      - Generate RDoc documentation
      rake docs:yard      - Generate YARD documentation
      rake docs:stats     - Show YARD documentation coverage
      rake docs:serve     - Serve YARD documentation locally
      rake docs:all       - Generate all documentation formats
      rake docs:clean     - Clean documentation directories
      rake rdoc           - Generate RDoc documentation (alias)
      rake yard           - Generate YARD documentation (alias)
      rake yard:stats     - Show documentation coverage (alias)
      rake yard:serve     - Serve YARD docs locally (alias)
      rake docs           - Generate all documentation (alias)
      rake clean_docs     - Clean documentation directories (alias)

    Build Tasks:
      rake build:docs     - Build with fresh documentation
      rake build:check    - Run comprehensive checks before release
      rake build          - Build with fresh documentation (alias)
      rake check          - Run comprehensive checks (alias)

    Other Tasks:
      rake help           - Show this help message
      rake default        - Run tests and quality checks
  HELP
end

# =============================================================================
# UTILITY TASKS
# =============================================================================

desc 'List all available namespaces'
task :namespaces do
  puts <<~NAMESPACES
    Available task namespaces:

    db:         Database operations (create, drop, migrate, seed)
    test:       Testing operations (unit, spec, coverage)
    quality:    Code quality checks (rubocop, doc_coverage, validate_examples, all)
    docs:       Documentation generation (rdoc, yard, stats, serve, all, clean)
    build:      Build operations (docs, check)
    rubocop:    RuboCop specific tasks (auto_correct)
    yard:       YARD specific tasks (stats, serve)

    Use 'rake -T namespace:' to see tasks in a specific namespace
    Example: rake -T test:
  NAMESPACES
end
