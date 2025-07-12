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

### Database Commands
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
   - `MenuCommand` - Interactive menu system (not exposed via CLI discovery)

3. **Actions** (`lib/blueprintsCLI/actions/`) - Business logic layer performing actual operations
4. **Database** (`lib/blueprintsCLI/database.rb`) - PostgreSQL interface with pgvector for semantic search
5. **Generators** (`lib/blueprintsCLI/generators/`) - AI-powered content generation
6. **Agents** (`lib/blueprintsCLI/agents/`) - Sublayer AI interaction layer

### Key Technologies
- **Thor** - Command-line interface framework with dynamic command registration
- **Sublayer** - AI framework for LLM interactions (configured for Gemini)
- **PostgreSQL + pgvector** - Database with 768-dimensional vector similarity search
- **Sequel ORM** - Database abstraction layer
- **TTY toolkit** - Rich terminal UI components (prompts, tables, menus, etc.)

### AI Integration
Uses Google Gemini API (`gemini-2.0-flash` model) for:
- Automatic description generation from code analysis
- Category classification and tagging
- Blueprint name generation
- Vector embeddings for semantic search (768-dimensional vectors via `text-embedding-004`)

### Database Schema
- `blueprints` table - Stores code, metadata, and vector embeddings
- `categories` table - Stores category definitions  
- `blueprints_categories` table - Many-to-many relationship

### Configuration System
- `lib/blueprintsCLI/config/sublayer.yml` - AI provider configuration
- `lib/blueprintsCLI/config/database.yml` - Database configuration for development/test
- `~/.config/BlueprintsCLI/config.yml` - User configuration (created by config command)
- Environment variables:
  - `GEMINI_API_KEY` or `GOOGLE_API_KEY` - Required for AI features
  - `BLUEPRINT_DATABASE_URL` or `DATABASE_URL` - Database connection
  - `RACK_ENV` - Environment setting (defaults to 'development')

### Command Pattern Implementation
Commands follow a consistent pattern:
1. Inherit from `BaseCommand` with auto-generated command names
2. Implement `execute(*args)` with subcommand routing
3. Delegate business logic to Action classes
4. Actions inherit from `Sublayer::Actions::Base`

The CLI auto-discovers commands by scanning `BlueprintsCLI::Commands` constants, excluding `BaseCommand` and `MenuCommand`.

### Interactive vs Direct Usage
- **Direct CLI**: `bin/blueprintsCLI <command> <subcommand> [args]`
- **Interactive Menu**: `bin/blueprintsCLI` (no args) launches `MenuCommand` with guided workflows

Both approaches route to the same underlying command classes but provide different user experiences.