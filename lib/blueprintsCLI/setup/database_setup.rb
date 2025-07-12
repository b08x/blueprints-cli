# frozen_string_literal: true

require 'sequel'
require 'pg'
require 'uri'

module BlueprintsCLI
  module Setup
    # DatabaseSetup handles PostgreSQL database configuration, connection testing,
    # and migration setup for BlueprintsCLI. It guides users through database
    # setup including connection string configuration and pgvector extension setup.
    class DatabaseSetup
      # Database configuration templates
      DATABASE_TEMPLATES = {
        local: {
          name: 'Local PostgreSQL',
          description: 'PostgreSQL running on localhost (default setup)',
          template: :local_default,
          requirements: ['PostgreSQL server running locally', 'pgvector extension available']
        },
        docker: {
          name: 'Docker PostgreSQL',
          description: 'PostgreSQL running in Docker container (auto-managed)',
          template: :docker_default,
          requirements: ['Docker installed and running'],
          features: ['Automatic container management', 'pgvector pre-installed',
            'Isolated environment']
        },
        remote: {
          name: 'Remote PostgreSQL',
          description: 'PostgreSQL running on remote server or cloud',
          template: :remote_example,
          requirements: ['Network access to database', 'pgvector extension installed']
        },
        custom: {
          name: 'Custom Configuration',
          description: 'Enter your own database connection string',
          template: '',
          requirements: ['Valid PostgreSQL connection string']
        }
      }.freeze

      # Initialize the database setup
      #
      # @param prompt [TTY::Prompt] TTY prompt instance
      # @param setup_data [Hash] Setup data storage
      def initialize(prompt, setup_data)
        @prompt = prompt
        @setup_data = setup_data
        @logger = BlueprintsCLI.logger
        @database_url = nil
        @connection = nil
      end

      # Get template URL for a given template type
      #
      # @param template_type [Symbol] Template identifier
      # @return [String] Database URL template
      def get_template_url(template_type)
        case template_type
        when :local_default
          'postgresql://postgres:password@localhost:5432/blueprints'
        when :docker_default
          BlueprintsCLI.configuration.build_database_url
        when :remote_example
          'postgresql://username:password@hostname:5432/database_name'
        else
          ''
        end
      end

      # Configure and test database connection
      #
      # @return [Boolean] True if database setup completed successfully
      def configure_and_test
        @logger.info('Setting up database configuration...')

        detect_existing_database
        configure_database_connection
        test_database_connection
        setup_database_schema
        finalize_database_setup

        true
      rescue StandardError => e
        @logger.failure("Database setup failed: #{e.message}")
        @logger.debug(e.backtrace.join("\n")) if ENV['DEBUG']
        false
      end

      private

      # Handle Docker PostgreSQL setup
      #
      # @param template [Hash] Docker template configuration
      def handle_docker_setup(_template)
        @logger.info('Setting up Docker PostgreSQL...')

        # Check if Docker is available
        unless docker_available?
          @logger.failure('Docker is not available or not running')
          handle_docker_not_available
          return
        end

        # Check if container already exists and is running
        if docker_container_running?
          @logger.success('PostgreSQL container is already running')
          use_existing = @prompt.yes?('Use existing Docker PostgreSQL container?', default: true)

          if use_existing
            @database_url = get_docker_database_url
            return
          elsif @prompt.yes?('Stop and recreate container?',
                             default: false)

            stop_and_remove_container
          end
        end

        # Start new Docker container
        start_docker_postgres
      end

      # Check if Docker is available and running
      #
      # @return [Boolean] True if Docker is available
      def docker_available?
        system('docker --version > /dev/null 2>&1') && system('docker info > /dev/null 2>&1')
      end

      # Check if PostgreSQL container is running
      #
      # @return [Boolean] True if container is running
      def docker_container_running?
        system('docker ps --filter "name=blueprintscli_postgres" --filter "status=running" | grep -q blueprintscli_postgres')
      end

      # Handle case when Docker is not available
      def handle_docker_not_available
        puts "\n❌ Docker Not Available"
        puts 'Docker is required for the Docker PostgreSQL option.'
        puts ''
        puts 'Installation options:'
        puts '1. Install Docker Desktop: https://www.docker.com/products/docker-desktop'
        puts '2. Install Docker Engine: https://docs.docker.com/engine/install/'
        puts '3. Choose a different database configuration'
        puts ''

        retry_with_different = @prompt.yes?('Choose a different database configuration?',
                                            default: true)
        unless retry_with_different
          raise StandardError, 'Docker is required for Docker PostgreSQL setup'
        end

        configure_database_connection
      end

      # Start Docker PostgreSQL container
      def start_docker_postgres
        @logger.info('Starting Docker PostgreSQL container...')

        docker_compose_path = File.join(BlueprintsCLI.root, 'docker', 'docker-compose.yml')

        unless File.exist?(docker_compose_path)
          @logger.failure("Docker Compose file not found at: #{docker_compose_path}")
          raise StandardError, 'Docker Compose configuration missing'
        end

        # Start the container
        @logger.info('Running: docker compose up -d')
        success = system("cd #{File.dirname(docker_compose_path)} && docker compose up -d")

        unless success
          @logger.failure('Failed to start Docker PostgreSQL container')
          raise StandardError, 'Docker container startup failed'
        end

        # Wait for container to be ready
        wait_for_docker_postgres

        @database_url = get_docker_database_url
        @logger.success('Docker PostgreSQL container started successfully!')
      end

      # Wait for Docker PostgreSQL to be ready
      def wait_for_docker_postgres
        @logger.info('Waiting for PostgreSQL container to be ready...')

        max_attempts = 30
        attempt = 0

        while attempt < max_attempts
          attempt += 1

          if docker_postgres_ready?
            @logger.success('PostgreSQL container is ready!')
            return
          end

          print '.'
          sleep 2
        end

        puts ''
        @logger.failure('PostgreSQL container did not become ready in time')
        raise StandardError, 'PostgreSQL container startup timeout'
      end

      # Check if Docker PostgreSQL is ready to accept connections
      #
      # @return [Boolean] True if PostgreSQL is ready
      def docker_postgres_ready?
        system('docker exec blueprintscli_postgres pg_isready -U postgres -d blueprints > /dev/null 2>&1')
      end

      # Get database URL for Docker PostgreSQL
      #
      # @return [String] Database connection URL
      def get_docker_database_url
        BlueprintsCLI.configuration.build_database_url
      end

      # Stop and remove existing Docker container
      def stop_and_remove_container
        @logger.info('Stopping and removing existing container...')

        system('docker stop blueprintscli_postgres > /dev/null 2>&1')
        system('docker rm blueprintscli_postgres > /dev/null 2>&1')

        @logger.success('Existing container removed')
      end

      # Detect existing database configuration
      def detect_existing_database
        existing_url = ENV['DATABASE_URL'] || ENV.fetch('BLUEPRINT_DATABASE_URL', nil)

        if existing_url
          @logger.info('Found existing database URL in environment')
          use_existing = @prompt.yes?('Use existing database configuration?', default: true)

          if use_existing
            @database_url = existing_url
            @logger.success('Using existing database configuration')
            return
          end
        end

        prompt_database_configuration
      end

      # Prompt user for database configuration
      def prompt_database_configuration
        puts "\n🗄️  Database Configuration"
        puts 'BlueprintsCLI requires PostgreSQL with pgvector extension for vector search.'
        puts ''

        display_database_templates
        template_choice = prompt_template_selection
        configure_from_template(template_choice)
      end

      # Display available database templates
      def display_database_templates
        puts 'Available database configurations:'
        DATABASE_TEMPLATES.each do |_key, template|
          puts "\n  #{template[:name]}:"
          puts "    #{template[:description]}"
          puts "    Requirements: #{template[:requirements].join(', ')}"

          puts "    Features: #{template[:features].join(', ')}" if template[:features]
        end
        puts ''
      end

      # Prompt user to select database template
      #
      # @return [Symbol] Selected template key
      def prompt_template_selection
        choices = DATABASE_TEMPLATES.map do |key, template|
          { name: template[:name], value: key }
        end

        @prompt.select('Select database configuration:', choices)
      end

      # Configure database from selected template
      #
      # @param template_key [Symbol] Template identifier
      def configure_from_template(template_key)
        template = DATABASE_TEMPLATES[template_key]

        case template_key
        when :custom
          @database_url = @prompt.ask('Enter database URL:')
        when :docker
          handle_docker_setup(template)
        else
          @database_url = prompt_template_customization(template)
        end

        validate_database_url
      end

      # Prompt user to customize template
      #
      # @param template [Hash] Database template
      # @return [String] Customized database URL
      def prompt_template_customization(template)
        template_url = get_template_url(template[:template])
        puts "\nTemplate: #{template_url}"

        use_template = @prompt.yes?('Use this template as-is?', default: true)
        return template_url if use_template

        # Parse template and prompt for customization
        uri = URI.parse(template_url)

        host = @prompt.ask('Database host:', default: uri.host)
        port = @prompt.ask('Database port:', default: uri.port.to_s).to_i
        username = @prompt.ask('Username:', default: uri.user)
        password = @prompt.mask('Password:', default: uri.password || '')
        database = @prompt.ask('Database name:', default: uri.path[1..]) # Remove leading slash

        "postgresql://#{username}:#{password}@#{host}:#{port}/#{database}"
      end

      # Validate database URL format
      def validate_database_url
        return if @database_url.nil? || @database_url.empty?

        begin
          uri = URI.parse(@database_url)
          unless %w[postgresql postgres].include?(uri.scheme)
            raise ArgumentError, 'URL must use postgresql:// or postgres:// scheme'
          end
        rescue URI::InvalidURIError => e
          @logger.failure("Invalid database URL: #{e.message}")
          retry_database_config
        rescue ArgumentError => e
          @logger.failure("Invalid database URL: #{e.message}")
          retry_database_config
        end
      end

      # Retry database configuration on validation failure
      def retry_database_config
        retry_setup = @prompt.yes?('Retry database configuration?', default: true)
        raise StandardError, 'Database configuration failed' unless retry_setup

        configure_database_connection
      end

      # Test database connection
      #
      # @return [Boolean] True if connection successful
      def test_database_connection
        @logger.info('Testing database connection...')

        begin
          @connection = Sequel.connect(@database_url)

          # Test basic connectivity
          @connection.test_connection
          @logger.success('✓ Database connection successful')

          # Check PostgreSQL version
          version_result = @connection.fetch('SELECT version()').first
          @logger.info("PostgreSQL version: #{version_result[:version]}")

          # Test pgvector extension
          test_pgvector_extension

          true
        rescue Sequel::DatabaseConnectionError => e
          @logger.failure("Database connection failed: #{e.message}")
          handle_connection_failure(e)
        rescue PG::ConnectionBad => e
          @logger.failure("PostgreSQL connection failed: #{e.message}")
          handle_connection_failure(e)
        end
      end

      # Test pgvector extension availability
      def test_pgvector_extension
        @logger.info('Checking pgvector extension...')

        begin
          # Check if pgvector extension exists
          extension_check = @connection.fetch(
            "SELECT * FROM pg_available_extensions WHERE name = 'vector'"
          ).first

          if extension_check
            @logger.success('✓ pgvector extension available')

            # Check if it's installed
            installed_check = @connection.fetch(
              "SELECT * FROM pg_extension WHERE extname = 'vector'"
            ).first

            if installed_check
              @logger.success('✓ pgvector extension already installed')
            else
              install_pgvector_extension
            end
          else
            @logger.failure('✗ pgvector extension not available')
            handle_pgvector_missing
          end
        rescue StandardError => e
          @logger.warn("Could not check pgvector extension: #{e.message}")
        end
      end

      # Install pgvector extension
      def install_pgvector_extension
        @logger.info('Installing pgvector extension...')

        begin
          @connection.run('CREATE EXTENSION IF NOT EXISTS vector')
          @logger.success('✓ pgvector extension installed')
        rescue Sequel::DatabaseError => e
          @logger.failure("Failed to install pgvector: #{e.message}")
          @logger.warn('You may need to install pgvector manually or contact your DBA')
        end
      end

      # Handle missing pgvector extension
      def handle_pgvector_missing
        puts "\n⚠️  pgvector Extension Missing"
        puts 'BlueprintsCLI requires the pgvector extension for vector similarity search.'
        puts ''
        puts 'Installation options:'
        puts '1. Install pgvector using your package manager'
        puts '2. Use Docker with a pgvector-enabled PostgreSQL image'
        puts '3. Contact your database administrator'
        puts ''
        puts 'See: https://github.com/pgvector/pgvector for installation instructions'

        continue_anyway = @prompt.yes?(
          'Continue setup without pgvector? (vector search will be disabled)', default: false
        )
        return if continue_anyway

        raise StandardError, 'pgvector extension required'
      end

      # Handle database connection failure
      #
      # @param error [StandardError] Connection error
      def handle_connection_failure(error)
        puts "\n❌ Database Connection Failed"
        puts "Error: #{error.message}"
        puts ''
        puts 'Common solutions:'
        puts '1. Ensure PostgreSQL server is running'
        puts '2. Check host, port, username, and password'
        puts '3. Verify database exists'
        puts '4. Check firewall settings'
        puts ''

        retry_connection = @prompt.yes?('Retry with different configuration?', default: true)
        raise StandardError, 'Database connection failed' unless retry_connection

        configure_database_connection
        test_database_connection
      end

      # Setup database schema
      def setup_database_schema
        @logger.info('Setting up database schema...')

        begin
          # Check if migrations are needed
          migration_needed = check_migration_status

          if migration_needed
            run_migrations
          else
            @logger.success('Database schema is up to date')
          end
        rescue StandardError => e
          @logger.failure("Schema setup failed: #{e.message}")
          handle_schema_failure(e)
        end
      end

      # Check if database migrations are needed
      #
      # @return [Boolean] True if migrations are needed
      def check_migration_status
        # Check if blueprints table exists
        tables = @connection.tables
        blueprint_table_exists = tables.include?(:blueprints)

        if blueprint_table_exists
          @logger.info('Existing database schema detected')
          false
        else
          @logger.info('New database - migrations needed')
          true
        end
      rescue StandardError
        # Assume migrations are needed if we can't check
        true
      end

      # Run database migrations
      def run_migrations
        @logger.info('Running database migrations...')

        begin
          # This would typically use the application's migration system
          # For now, we'll create a basic schema
          create_basic_schema
          @logger.success('✓ Database migrations completed')
        rescue StandardError => e
          @logger.failure("Migration failed: #{e.message}")
          raise e
        end
      end

      # Create basic database schema
      def create_basic_schema
        @logger.info('Creating basic database schema...')

        # Create categories table
        @connection.run <<~SQL
          CREATE TABLE IF NOT EXISTS categories (
            id SERIAL PRIMARY KEY,
            title VARCHAR(255) UNIQUE NOT NULL,
            description TEXT,
            color VARCHAR(7),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        SQL

        # Handle schema migration: rename 'name' column to 'title' if it exists
        migrate_categories_schema

        # Create blueprints table with vector column
        @connection.run <<~SQL
          CREATE TABLE IF NOT EXISTS blueprints (
            id SERIAL PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            description TEXT,
            code TEXT NOT NULL,
            language VARCHAR(50),
            tags TEXT[],
            embedding vector(768),
            metadata JSONB DEFAULT '{}',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        SQL

        # Create junction table for categories
        @connection.run <<~SQL
          CREATE TABLE IF NOT EXISTS blueprints_categories (
            blueprint_id INTEGER REFERENCES blueprints(id) ON DELETE CASCADE,
            category_id INTEGER REFERENCES categories(id) ON DELETE CASCADE,
            PRIMARY KEY (blueprint_id, category_id)
          )
        SQL

        # Create indexes
        @connection.run 'CREATE INDEX IF NOT EXISTS idx_blueprints_embedding ON blueprints USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)'
        @connection.run 'CREATE INDEX IF NOT EXISTS idx_blueprints_language ON blueprints(language)'
        @connection.run 'CREATE INDEX IF NOT EXISTS idx_blueprints_created_at ON blueprints(created_at)'

        @logger.success('✓ Basic schema created')
      end

      # Handle schema setup failure
      #
      # @param error [StandardError] Schema error
      def handle_schema_failure(error)
        puts "\n❌ Database Schema Setup Failed"
        puts "Error: #{error.message}"

        continue_anyway = @prompt.yes?('Continue setup? (you can run migrations manually later)',
                                       default: true)
        return if continue_anyway

        raise error
      end

      # Finalize database setup
      def finalize_database_setup
        @setup_data[:database] = {
          url: @database_url,
          configured: true,
          pgvector_enabled: pgvector_available?,
          schema_ready: true
        }

        @logger.success('Database setup completed!')
        display_database_summary
      end

      # Check if pgvector is available
      #
      # @return [Boolean] True if pgvector is installed
      def pgvector_available?
        return false unless @connection

        begin
          result = @connection.fetch("SELECT * FROM pg_extension WHERE extname = 'vector'").first
          !result.nil?
        rescue StandardError
          false
        end
      end

      # Display database configuration summary
      def display_database_summary
        puts "\n📊 Database Configuration Summary:"

        uri = URI.parse(@database_url)
        puts "  Host: #{uri.host}:#{uri.port}"
        puts "  Database: #{uri.path[1..]}"
        puts "  Username: #{uri.user}"
        puts "  pgvector: #{pgvector_available? ? 'Enabled' : 'Disabled'}"
        puts ''
      end

      # Configure database connection (entry point)
      def configure_database_connection
        detect_existing_database unless @database_url
      end

      # Migrate categories schema from 'name' to 'title' column
      def migrate_categories_schema
        @logger.info('Checking for categories schema migration...')

        begin
          # Check if 'name' column exists (old schema)
          name_exists = @connection.fetch(
            "SELECT column_name FROM information_schema.columns WHERE table_name = 'categories' AND column_name = 'name'"
          ).first

          # Check if 'title' column exists (new schema)
          title_exists = @connection.fetch(
            "SELECT column_name FROM information_schema.columns WHERE table_name = 'categories' AND column_name = 'title'"
          ).first

          if name_exists && !title_exists
            @logger.info('Migrating categories table: renaming "name" column to "title"')
            @connection.run('ALTER TABLE categories RENAME COLUMN name TO title')
            @logger.success('✓ Categories schema migration completed')
          elsif title_exists
            @logger.info('Categories schema is already up to date')
          else
            @logger.info('Categories table not found or has unexpected schema')
          end
        rescue StandardError => e
          @logger.warn("Categories schema migration failed: #{e.message}")
          # Don't fail the entire setup for migration issues
        end
      end
    end
  end
end
