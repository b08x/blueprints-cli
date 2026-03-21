# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

### Development Commands
- `bundle install` - Install Ruby dependencies
- `bin/blueprintsCLI` - Run the CLI application (launches interactive menu if no args)
- `bundle exec rspec` - Run tests (RSpec test framework)
- `bundle exec rubocop` - Run linting/code style checks
- `bundle exec yard doc` - Generate documentation
- `bundle exec pry` - Start interactive Ruby console
- `bin/blueprintsCLI docs generate <file_path>` - Generate AI-powered YARD documentation for Ruby files

### Database Commands
Note: The Rakefile references `config/database.yml` but the actual file is at `lib/blueprintsCLI/config/database.yml`. Database migrations are located in `lib/blueprintsCLI/db/migrate/`.

- `rake db:create` - Create the PostgreSQL database
- `rake db:migrate` - Run database migrations
- `rake db:drop` - Drop the database
- `rake db:seed` - Seed the database with initial data

### CLI Usage
The main entry point is `bin/blueprintsCLI` which provides:

#### Direct Command Usage
- `bin/blueprintsCLI blueprint submit <file_or_code>` - Submit a new code blueprint
- `bin/blueprintsCLI blueprint list [--format FORMAT]` - List all blueprints
- `bin/blueprintsCLI blueprint search <query>` - Search blueprints using vector similarity
- `bin/blueprintsCLI blueprint view <id> [--analyze]` - View a specific blueprint
- `bin/blueprintsCLI blueprint edit <id>` - Edit an existing blueprint
- `bin/blueprintsCLI blueprint delete <id> [--force]` - Delete a blueprint
- `bin/blueprintsCLI blueprint export <id> [output_file]` - Export blueprint code
- `bin/blueprintsCLI config [setup|show|edit|validate|reset]` - Manage configuration
- `bin/blueprintsCLI docs generate <file_path>` - Generate AI-powered YARD documentation

#### Interactive Menu
- `bin/blueprintsCLI` - Launches interactive menu system for all operations

## Architecture Overview

### Command Structure
The application uses a dynamic command discovery system:

1. **CLI Layer** (`lib/blueprintsCLI/cli.rb`) - Thor-based interface that auto-discovers command classes
2. **Commands** (`lib/blueprintsCLI/commands/`) - Command classes that handle routing and validation:
   - `BaseCommand` - Abstract base providing logging and command metadata
   - `BlueprintCommand` - Main blueprint operations with subcommand routing  
   - `ConfigCommand` - Configuration management operations
   - `DocsCommand` - AI-powered YARD documentation generation
   - `MenuCommand` - Interactive menu system (not exposed via CLI discovery)

3. **Actions** (`lib/blueprintsCLI/actions/`) - Business logic layer performing actual operations
4. **Database** (`lib/blueprintsCLI/database.rb`) - PostgreSQL interface with pgvector for semantic search
5. **Generators** (`lib/blueprintsCLI/generators/`) - AI-powered content generation
6. **Agents** (`lib/blueprintsCLI/agents/`) - Sublayer AI interaction layer
7. **Services** (`lib/blueprintsCLI/services/`) - Service layer including YardocService for documentation generation

### Key Technologies
- **Thor** - Command-line interface framework with dynamic command registration
- **Sublayer** - AI framework for LLM interactions (configured for Gemini)
- **RubyLLM** - Multi-provider LLM interface supporting Gemini, OpenAI, Anthropic, DeepSeek
- **PostgreSQL + pgvector** - Database with 768-dimensional vector similarity search
- **Sequel ORM** - Database abstraction layer
- **TTY toolkit** - Rich terminal UI components (prompts, tables, menus, etc.)
- **TTY::Config** - Unified configuration management with environment variable mapping

### AI Integration
Uses Google Gemini API (`gemini-2.0-flash` model) for:
- Automatic description generation from code analysis
- Category classification and tagging
- Blueprint name generation
- Vector embeddings for semantic search (768-dimensional vectors via `text-embedding-004`)
- AI-powered YARD documentation generation with comprehensive prompting system

### Database Schema
- `blueprints` table - Stores code, metadata, and vector embeddings
- `categories` table - Stores category definitions  
- `blueprints_categories` table - Many-to-many relationship

### Configuration System
Uses TTY::Config for unified configuration management with multiple sources and validation:

- `lib/blueprintsCLI/config/*.yml` - Default configuration files
- `~/.config/BlueprintsCLI/config.yml` - User configuration (created by config command)
- Environment variables with `BLUEPRINTS_` prefix automatically mapped
- Backward compatibility with legacy config files

Key environment variables:
- `GEMINI_API_KEY` or `GOOGLE_API_KEY` - Required for AI features
- `OPENAI_API_KEY` - For OpenAI provider
- `ANTHROPIC_API_KEY` - For Anthropic provider  
- `DEEPSEEK_API_KEY` - For DeepSeek provider
- `BLUEPRINT_DATABASE_URL` or `DATABASE_URL` - Database connection
- `RACK_ENV` - Environment setting (defaults to 'development')

Configuration validation ensures required values are present and properly formatted.

### Command Pattern Implementation
Commands follow a consistent pattern:
1. Inherit from `BaseCommand` with auto-generated command names
2. Implement `execute(*args)` with subcommand routing
3. Delegate business logic to Action classes
4. Actions inherit from `Sublayer::Actions::Base`

The CLI auto-discovers commands by scanning `BlueprintsCLI::Commands` constants, excluding `BaseCommand` and `MenuCommand`. The system dynamically registers Thor commands based on class names, allowing for easy command extension.

### Interactive vs Direct Usage
- **Direct CLI**: `bin/blueprintsCLI <command> <subcommand> [args]`
- **Interactive Menu**: `bin/blueprintsCLI` (no args) launches `MenuCommand` with guided workflows

Both approaches route to the same underlying command classes but provide different user experiences.

## Development Notes

### Important File Locations
- Database configuration: `lib/blueprintsCLI/config/database.yml` (not `config/database.yml`)
- Migrations: `lib/blueprintsCLI/db/migrate/`
- Models: `lib/blueprintsCLI/db/models/`
- The Rakefile references the wrong config path and needs to be updated or migration commands run from the correct context

### Testing Framework
- Uses RSpec test framework (`bundle exec rspec`)
- Test files located in `spec/` directory
- Includes model specs, service specs, and request specs
- Factory definitions in `spec/factories.rb`

### Code Quality Tools
- RuboCop for linting with multiple extensions (rspec, sequel, shopify, etc.)
- YARD for documentation generation
- Ruby LSP and Solargraph for development tooling
- AI-powered documentation generation via DocsCommand

### Enhanced Logging System
BlueprintsCLI now features an enhanced logging system that automatically captures context information:

#### Features
- **Automatic Context Capture**: Logs automatically include class name, method name, file, and line number
- **Configurable Detail Levels**: Choose between minimal, standard, or full context detail
- **Performance Optimized**: Context extraction is cached and optimized for performance
- **Backward Compatible**: All existing logging calls continue to work unchanged

#### Configuration Options (config.yml)
```yaml
logger:
  context_enabled: true                    # Enable/disable context capture
  context_detail_level: full              # Options: minimal, standard, full
  context_cache_size: 1000                # Cache size for performance optimization
```

#### Context Detail Levels
- **minimal**: Just class and method names
- **standard**: Class, method, and file name
- **full**: Class, method, file name, line number, and full path

#### Usage
The enhanced logging works automatically with existing logging calls:
```ruby
logger.info("Processing data")
# Output: ℹ info Processing data class=MyClass method=process_data file=my_class.rb line=45
```

### Architecture Patterns
- Commands use Thor for CLI interface with dynamic discovery
- Business logic separated into Action classes inheriting from Sublayer::Actions::Base
- Service layer for complex operations like YARD documentation generation
- Database interface abstraction with pgvector for semantic search
- Unified configuration management with TTY::Config supporting validation and environment mapping