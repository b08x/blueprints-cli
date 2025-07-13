# BlueprintsCLI

A command-line tool for storing and finding code snippets using semantic search.

## What it does

BlueprintsCLI stores code snippets in a PostgreSQL database and finds them using vector similarity search. It includes an AI integration that generates descriptions and categories automatically.

The tool has two interfaces:

- Interactive menu system for guided workflows
- Direct command-line interface for specific operations

## Features

### Code management

- Store code snippets with metadata
- List stored snippets in table, summary, or JSON format
- Search snippets using natural language queries
- View individual snippets with optional AI analysis
- Edit snippet metadata
- Delete snippets
- Export snippet code to files

### AI integration

- Uses Google Gemini API for text generation and embeddings
- Generates descriptions automatically when storing snippets
- Assigns categories automatically
- Creates 768-dimensional vector embeddings for semantic search
- Provides code analysis and improvement suggestions

### User interface

- Interactive menu system using TTY toolkit components
- Command-line interface using Thor framework
- Terminal tables, prompts, and progress indicators
- Log viewing with pagination

## Requirements

- Ruby 3.0 or later
- PostgreSQL with pgvector extension
- Google Gemini API key

## Installation

```bash
# Clone repository
git clone <repository-url>
cd blueprintsCLI

# Install Ruby dependencies
bundle install

# Create database
rake db:create
rake db:migrate

# Set up configuration
bin/blueprintsCLI config setup
```

## Configuration

### Environment variables

```bash
export GEMINI_API_KEY="your-gemini-api-key"
export DATABASE_URL="postgresql://postgres:password@localhost:5432/blueprints"
```

### Interactive setup

```bash
bin/blueprintsCLI config setup
```

## Usage

### Interactive mode

```bash
bin/blueprintsCLI
```

### Direct commands

#### Store code

```bash
bin/blueprintsCLI blueprint submit path/to/file.rb
bin/blueprintsCLI blueprint submit "puts 'Hello World'"
```

#### List code snippets

```bash
bin/blueprintsCLI blueprint list
bin/blueprintsCLI blueprint list --format json
```

#### Search code snippets

```bash
bin/blueprintsCLI blueprint search "http server ruby"
```

#### View specific snippet

```bash
bin/blueprintsCLI blueprint view 42
bin/blueprintsCLI blueprint view 42 --analyze
```

#### Other operations

```bash
bin/blueprintsCLI blueprint edit 42
bin/blueprintsCLI blueprint delete 42
bin/blueprintsCLI blueprint export 42 output.rb
```

#### Configuration commands

```bash
bin/blueprintsCLI config show
bin/blueprintsCLI config setup
bin/blueprintsCLI config validate
bin/blueprintsCLI config reset
```

## Architecture

The application follows this structure:

```
CLI Layer → Commands → Actions → Database/AI Services
```

- **CLI Layer**: Thor framework handles command parsing and routing
- **Commands**: Route operations and validate input
- **Actions**: Execute business logic (inherit from Sublayer::Actions::Base)
- **Database**: PostgreSQL with Sequel ORM and pgvector extension
- **AI Services**: Google Gemini API via Sublayer framework

### Database schema

- `blueprints` table: stores code, metadata, and vector embeddings
- `categories` table: stores category definitions
- `blueprints_categories` table: many-to-many relationships

### Configuration

Uses TTY::Config for configuration management with support for:

- Environment variables (with `BLUEPRINTS_` prefix)
- YAML configuration files
- Validation rules
- Multiple provider configurations

## Development

### Run tests

```bash
bundle exec rspec
```

### Run linter

```bash
bundle exec rubocop
```

### Generate documentation

```bash
bundle exec yard doc
```

### Interactive console

```bash
bundle exec pry
```

## Dependencies

### Core libraries

- Thor: command-line interface framework
- Sequel: database ORM
- TTY toolkit: terminal user interface components
- Sublayer: AI framework wrapper

### External services

- PostgreSQL: database storage
- pgvector: vector similarity search extension
- Google Gemini API: text generation and embeddings

## License

MIT License

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and add tests
4. Run tests and linter
5. Submit pull request
