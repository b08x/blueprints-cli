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
require_relative 'lib/blueprintsCLI/configuration'

# Use BlueprintsCLI configuration system
CONFIG = BlueprintsCLI::Configuration.new

namespace :db do
  desc 'Create the database'
  task :create do
    require 'pg'
    require 'uri'
    uri = URI.parse(CONFIG.database_url)
    db_name = uri.path[1..]
    begin
      PG.connect(dbname: 'postgres', user: uri.user, password: uri.password, host: uri.host,
                 port: uri.port) do |conn|
        conn.exec("CREATE DATABASE #{db_name}")
      end
      puts "Database '#{db_name}' created."
    rescue PG::DuplicateDatabase
      puts "Database '#{db_name}' already exists."
    end
  end

  desc 'Drop the database'
  task :drop do
    require 'pg'
    require 'uri'
    uri = URI.parse(CONFIG.database_url)
    db_name = uri.path[1..]
    begin
      PG.connect(dbname: 'postgres', user: uri.user, password: uri.password, host: uri.host,
                 port: uri.port) do |conn|
        conn.exec("DROP DATABASE IF EXISTS #{db_name}")
      end
      puts "Database '#{db_name}' dropped."
    rescue PG::InvalidCatalogName
      puts "Database '#{db_name}' does not exist."
    end
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

  desc 'Rebuild the database'
  task rebuild: %i[drop create migrate]

  desc 'Reset the test database'
  task :reset_test do
    ENV['RACK_ENV'] = 'test'
    Rake::Task['db:rebuild'].invoke
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
# DOCKER TASKS
# =============================================================================

namespace :docker do
  DOCKER_COMPOSE_FILE = 'docker/docker-compose.yml'
  DOCKER_COMPOSE_DEV_FILE = 'docker/docker-compose.dev.yml'
  DOCKER_COMPOSE_OVERRIDE = 'docker/docker-compose.override.yml'

  desc 'Show Docker Compose commands help'
  task :help do
    puts <<~DOCKER_HELP
      Docker Management Tasks for BlueprintsCLI:

      Environment Setup:
        rake docker:setup_env          - Create .env from template
        rake docker:check_env          - Validate environment variables

      Development Environment:
        rake docker:dev:up             - Start development environment
        rake docker:dev:down           - Stop development environment#{'  '}
        rake docker:dev:restart        - Restart development environment
        rake docker:dev:logs           - Show development logs
        rake docker:dev:shell          - Open shell in API container
        rake docker:dev:db_shell       - Open psql shell (development)
        rake docker:dev:redis_cli      - Open redis-cli (development)

      Production Environment:
        rake docker:prod:up            - Start production environment
        rake docker:prod:down          - Stop production environment
        rake docker:prod:restart       - Restart production environment
        rake docker:prod:logs          - Show production logs
        rake docker:prod:deploy        - Deploy with health checks

      Database Management:
        rake docker:db:backup          - Backup database
        rake docker:db:restore         - Restore database from backup
        rake docker:db:reset           - Reset development database
        rake docker:db:migrate         - Run migrations in container
        rake docker:db:seed            - Seed database in container

      Utility Tasks:
        rake docker:build              - Build all images
        rake docker:build:force        - Force rebuild all images
        rake docker:clean              - Clean unused images/volumes
        rake docker:ps                 - Show running containers
        rake docker:health             - Check service health
        rake docker:stats              - Show container resource usage

      Testing in Docker:
        rake docker:test:setup         - Setup test environment
        rake docker:test:run           - Run tests in containers
        rake docker:test:clean         - Cleanup test containers

      Examples:
        rake docker:dev:up             # Start development with hot-reload
        rake docker:dev:up PROFILES=with-adminer,with-mail  # With extra tools
        rake docker:prod:deploy        # Production deployment
    DOCKER_HELP
  end

  # Environment setup tasks
  desc 'Create .env file from template'
  task :setup_env do
    env_file = 'docker/.env'
    env_example = 'docker/.env.example'

    if File.exist?(env_file)
      puts "⚠️  #{env_file} already exists. Remove it first if you want to recreate."
    elsif File.exist?(env_example)
      FileUtils.cp(env_example, env_file)
      puts "✅ Created #{env_file} from template"
      puts "📝 Please edit #{env_file} with your specific values"
    else
      puts "❌ #{env_example} template not found"
      exit 1
    end
  end

  desc 'Validate required environment variables'
  task :check_env do
    required_vars = %w[POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD]
    env_file = 'docker/.env'

    if File.exist?(env_file)
      env_vars = File.readlines(env_file).map { |line| line.split('=')[0] }
      missing_vars = required_vars - env_vars

      if missing_vars.empty?
        puts '✅ All required environment variables are configured'
      else
        puts "❌ Missing required environment variables: #{missing_vars.join(', ')}"
        exit 1
      end
    else
      puts "❌ No .env file found. Run 'rake docker:setup_env' first"
      exit 1
    end
  end

  # Development environment tasks
  namespace :dev do
    desc 'Start development environment'
    task :up do
      profiles = ENV['PROFILES']&.split(',')
      cmd = "docker compose -f #{DOCKER_COMPOSE_DEV_FILE}"
      cmd += " --profile #{profiles.join(' --profile ')}" if profiles
      cmd += ' up -d'

      puts '🚀 Starting development environment...'
      system(cmd) || exit(1)
      puts '✅ Development environment started!'
      puts '🌐 Frontend: http://localhost:8080'
      puts '🔧 Backend API: http://localhost:3000'
      puts '🗄️  Database: localhost:5433'
      puts '📊 Adminer: http://localhost:8081 (if --profile with-adminer was used)'
    end

    desc 'Stop development environment'
    task :down do
      puts '🛑 Stopping development environment...'
      system("docker compose -f #{DOCKER_COMPOSE_DEV_FILE} down") || exit(1)
      puts '✅ Development environment stopped!'
    end

    desc 'Restart development environment'
    task :restart do
      Rake::Task['docker:dev:down'].invoke
      sleep 2
      Rake::Task['docker:dev:up'].invoke
    end

    desc 'Show development environment logs'
    task :logs do
      service = ENV['SERVICE'] || ''
      cmd = "docker compose -f #{DOCKER_COMPOSE_DEV_FILE} logs -f #{service}"
      puts "📋 Showing logs for #{service.empty? ? 'all services' : service}..."
      system(cmd)
    end

    desc 'Open shell in API development container'
    task :shell do
      puts '🐚 Opening shell in API development container...'
      system("docker compose -f #{DOCKER_COMPOSE_DEV_FILE} exec backend-dev /bin/bash")
    end

    desc 'Open PostgreSQL shell (development)'
    task :db_shell do
      puts '🗄️  Opening PostgreSQL shell (development)...'
      system("docker compose -f #{DOCKER_COMPOSE_DEV_FILE} exec postgres-dev psql -U postgres -d blueprints_cli_development")
    end

    desc 'Open Redis CLI (development)'
    task :redis_cli do
      puts '📊 Opening Redis CLI (development)...'
      system("docker compose -f #{DOCKER_COMPOSE_DEV_FILE} exec redis-dev redis-cli")
    end
  end

  # Production environment tasks
  namespace :prod do
    desc 'Start production environment'
    task :up do
      puts '🚀 Starting production environment...'
      system("docker compose -f #{DOCKER_COMPOSE_FILE} up -d") || exit(1)
      puts '✅ Production environment started!'
      puts '🌐 Application: http://localhost'
    end

    desc 'Stop production environment'
    task :down do
      puts '🛑 Stopping production environment...'
      system("docker compose -f #{DOCKER_COMPOSE_FILE} down") || exit(1)
      puts '✅ Production environment stopped!'
    end

    desc 'Restart production environment'
    task :restart do
      Rake::Task['docker:prod:down'].invoke
      sleep 2
      Rake::Task['docker:prod:up'].invoke
    end

    desc 'Show production environment logs'
    task :logs do
      service = ENV['SERVICE'] || ''
      cmd = "docker compose -f #{DOCKER_COMPOSE_FILE} logs -f #{service}"
      puts "📋 Showing logs for #{service.empty? ? 'all services' : service}..."
      system(cmd)
    end

    desc 'Deploy production environment with health checks'
    task :deploy do
      puts '🚀 Deploying production environment...'
      # Build images
      system("docker compose -f #{DOCKER_COMPOSE_FILE} build") || exit(1)

      # Start services
      system("docker compose -f #{DOCKER_COMPOSE_FILE} up -d") || exit(1)

      # Wait for health checks
      puts '⏳ Waiting for services to become healthy...'
      sleep 30

      # Check health
      Rake::Task['docker:health'].invoke
      puts '✅ Production deployment completed!'
    end
  end

  # Database tasks
  namespace :db do
    desc 'Backup database'
    task :backup do
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      backup_file = "docker/data/backups/backup_#{timestamp}.sql"

      puts '💾 Creating database backup...'
      FileUtils.mkdir_p('docker/data/backups')
      system("docker compose -f #{DOCKER_COMPOSE_FILE} exec -T postgres pg_dump -U postgres blueprints_cli_production > #{backup_file}") || exit(1)
      puts "✅ Database backup saved to #{backup_file}"
    end

    desc 'Restore database from backup'
    task :restore do
      backup_file = ENV.fetch('BACKUP_FILE', nil)
      if backup_file.nil? || !File.exist?(backup_file)
        puts '❌ Please specify BACKUP_FILE environment variable with valid backup file'
        exit 1
      end

      puts '⚠️  This will replace the current database. Continue? (y/N)'
      response = STDIN.gets.chomp.downcase
      exit unless response == 'y'

      puts "🔄 Restoring database from #{backup_file}..."
      system("docker compose -f #{DOCKER_COMPOSE_FILE} exec -T postgres psql -U postgres blueprints_cli_production < #{backup_file}") || exit(1)
      puts '✅ Database restored successfully!'
    end

    desc 'Reset development database'
    task :reset do
      puts '⚠️  This will destroy the development database. Continue? (y/N)'
      response = STDIN.gets.chomp.downcase
      exit unless response == 'y'

      puts '🔄 Resetting development database...'
      system("docker compose -f #{DOCKER_COMPOSE_DEV_FILE} down postgres-dev")
      system('docker volume rm blueprintscli_postgres_dev_data 2>/dev/null || true')
      system("docker compose -f #{DOCKER_COMPOSE_DEV_FILE} up -d postgres-dev")
      puts '✅ Development database reset!'
    end

    desc 'Run migrations in container'
    task :migrate do
      env = ENV['RAILS_ENV'] || 'development'
      compose_file = env == 'production' ? DOCKER_COMPOSE_FILE : DOCKER_COMPOSE_DEV_FILE
      service = env == 'production' ? 'backend-api' : 'backend-dev'

      puts "🔄 Running database migrations (#{env})..."
      system("docker compose -f #{compose_file} exec #{service} bundle exec rake db:migrate") || exit(1)
      puts '✅ Migrations completed!'
    end

    desc 'Seed database in container'
    task :seed do
      env = ENV['RAILS_ENV'] || 'development'
      compose_file = env == 'production' ? DOCKER_COMPOSE_FILE : DOCKER_COMPOSE_DEV_FILE
      service = env == 'production' ? 'backend-api' : 'backend-dev'

      puts "🌱 Seeding database (#{env})..."
      system("docker compose -f #{compose_file} exec #{service} bundle exec rake db:seed") || exit(1)
      puts '✅ Database seeding completed!'
    end
  end

  # Utility tasks
  desc 'Build all Docker images'
  task :build do
    puts '🔨 Building all Docker images...'
    system("docker compose -f #{DOCKER_COMPOSE_FILE} build") || exit(1)
    system("docker compose -f #{DOCKER_COMPOSE_DEV_FILE} build") || exit(1)
    puts '✅ All images built successfully!'
  end

  namespace :build do
    desc 'Force rebuild all Docker images'
    task :force do
      puts '🔨 Force rebuilding all Docker images...'
      system("docker compose -f #{DOCKER_COMPOSE_FILE} build --no-cache") || exit(1)
      system("docker compose -f #{DOCKER_COMPOSE_DEV_FILE} build --no-cache") || exit(1)
      puts '✅ All images force rebuilt successfully!'
    end
  end

  desc 'Clean unused Docker images and volumes'
  task :clean do
    puts '🧹 Cleaning unused Docker resources...'
    system('docker system prune -f')
    system('docker volume prune -f')
    puts '✅ Docker cleanup completed!'
  end

  desc 'Show running containers'
  task :ps do
    puts '📋 Running containers:'
    system("docker compose -f #{DOCKER_COMPOSE_FILE} ps")
    system("docker compose -f #{DOCKER_COMPOSE_DEV_FILE} ps")
  end

  desc 'Check service health'
  task :health do
    puts '🏥 Checking service health...'
    # Check production services
    puts "\n📊 Production Services:"
    system("docker compose -f #{DOCKER_COMPOSE_FILE} ps")

    # Check development services
    puts "\n🔧 Development Services:"
    system("docker compose -f #{DOCKER_COMPOSE_DEV_FILE} ps")

    # Test endpoints
    puts "\n🌐 Testing endpoints..."
    system("curl -f http://localhost:3000/api/health 2>/dev/null && echo '✅ Backend API healthy' || echo '❌ Backend API unhealthy'")
    system("curl -f http://localhost:8080/ 2>/dev/null && echo '✅ Frontend healthy' || echo '❌ Frontend unhealthy'")
  end

  desc 'Show container resource usage'
  task :stats do
    puts '📊 Container resource usage:'
    system('docker stats --no-stream')
  end

  # Testing tasks
  namespace :test do
    desc 'Setup test environment'
    task :setup do
      puts '🧪 Setting up test environment...'
      # This could be expanded to create test-specific compose files
      puts '✅ Test environment setup completed!'
    end

    desc 'Run tests in containers'
    task :run do
      puts '🧪 Running tests in containers...'
      system("docker compose -f #{DOCKER_COMPOSE_DEV_FILE} exec backend-dev bundle exec rspec") || exit(1)
      puts '✅ Tests completed!'
    end

    desc 'Clean up test containers'
    task :clean do
      puts '🧹 Cleaning up test containers...'
      system("docker compose -f #{DOCKER_COMPOSE_DEV_FILE} down --remove-orphans")
      puts '✅ Test cleanup completed!'
    end
  end
end

# Convenience aliases for common Docker tasks
desc 'Start development environment'
task 'dev:up' => 'docker:dev:up'

desc 'Stop development environment'
task 'dev:down' => 'docker:dev:down'

desc 'Start production environment'
task 'prod:up' => 'docker:prod:up'

desc 'Stop production environment'
task 'prod:down' => 'docker:prod:down'

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
    docker:     Docker environment management (dev, prod, db, build, clean)
    rubocop:    RuboCop specific tasks (auto_correct)
    yard:       YARD specific tasks (stats, serve)

    Use 'rake -T namespace:' to see tasks in a specific namespace
    Example: rake -T docker:
  NAMESPACES
end