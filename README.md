# BlueprintsCLI

A powerful command-line interface for managing, searching, and organizing reusable code snippets with AI-powered semantic search and analysis capabilities.

## 🎯 Intention

BlueprintsCLI transforms the way developers manage and discover reusable code patterns. Rather than losing valuable code snippets in scattered files or forgetting clever solutions to common problems, this tool provides:

- **Intelligent Organization**: Store code blueprints with automatic categorization and rich metadata
- **Semantic Search**: Find relevant code using natural language queries powered by vector embeddings
- **AI Enhancement**: Automatically generate descriptions, categories, and improvement suggestions
- **Developer-Friendly**: Rich CLI interface with both interactive menus and direct commands

## ⚡ Key Features

### Core Functionality
- **Blueprint Management**: Create, view, edit, list, and delete code blueprints
- **Semantic Search**: Vector-based similarity search using Google Gemini embeddings (768-dimensional)
- **Category System**: Automatic and manual categorization with many-to-many relationships
- **Rich Metadata**: Automatic description generation and improvement analysis
- **Export Capabilities**: Export blueprints with optional metadata inclusion

### AI Integration
- **Google Gemini Integration**: Uses `gemini-2.0-flash` for analysis and `text-embedding-004` for search
- **Sublayer Framework**: AI-powered content generation and analysis
- **Ruby LLM Support**: Multi-provider AI configuration for flexibility
- **Automatic Enhancement**: AI-generated descriptions, categories, and optimization suggestions

### Developer Experience
- **Interactive Menu System**: Guided workflows for all operations
- **Direct CLI Commands**: Efficient command-line interface for power users
- **Rich Terminal UI**: TTY toolkit for beautiful tables, prompts, and progress indicators
- **Flexible Configuration**: TTY::Config-based unified configuration management
- **Database Integration**: PostgreSQL with pgvector extension for performance

## 🚀 Installation

### Prerequisites
- Ruby 3.0+
- PostgreSQL with pgvector extension
- Google Gemini API key

### Setup
```bash
# Clone the repository
git clone <repository-url>
cd blueprintsCLI

# Install dependencies
bundle install

# Create and migrate database
rake db:create
rake db:migrate

# Configure the application
bin/blueprintsCLI config setup

# Seed with initial data (optional)
rake db:seed
```

### Configuration
Set up your environment variables:
```bash
export GEMINI_API_KEY="your-gemini-api-key"
export BLUEPRINT_DATABASE_URL="postgres://localhost/blueprints_development"
```

Or use the interactive configuration:
```bash
bin/blueprintsCLI config setup
```

## 📖 Usage

### Interactive Mode
Launch the interactive menu system:
```bash
bin/blueprintsCLI
```

### Direct Commands

#### Blueprint Management
```bash
# Submit a new blueprint
bin/blueprintsCLI blueprint submit path/to/file.rb
bin/blueprintsCLI blueprint submit "puts 'Hello World'"

# List all blueprints
bin/blueprintsCLI blueprint list
bin/blueprintsCLI blueprint list --format json

# Search blueprints
bin/blueprintsCLI blueprint search "http server ruby"

# View a specific blueprint
bin/blueprintsCLI blueprint view 42
bin/blueprintsCLI blueprint view 42 --analyze

# Edit a blueprint
bin/blueprintsCLI blueprint edit 42

# Delete a blueprint
bin/blueprintsCLI blueprint delete 42
bin/blueprintsCLI blueprint delete 42 --force

# Export blueprint code
bin/blueprintsCLI blueprint export 42 output.rb
```

#### Configuration Management
```bash
# Show current configuration
bin/blueprintsCLI config show

# Interactive setup
bin/blueprintsCLI config setup

# Test configuration
bin/blueprintsCLI config test

# Migrate old config files
bin/blueprintsCLI config migrate

# Reset to defaults
bin/blueprintsCLI config reset
```

### Development Commands
```bash
# Run tests
bundle exec rspec

# Run linting
bundle exec rubocop

# Generate documentation
bundle exec yard doc

# Interactive console
bundle exec pry
```

## 🏗️ Architecture

### Command Structure
```
CLI Layer (Thor) → Commands → Actions → Database/AI Services
```

- **CLI Layer**: Thor-based interface with dynamic command discovery
- **Commands**: Routing and validation (`BlueprintCommand`, `ConfigCommand`)
- **Actions**: Business logic layer inheriting from `Sublayer::Actions::Base`
- **Services**: Database operations and AI integrations

### Key Technologies
- **Framework**: Thor CLI framework with dynamic command registration
- **AI**: Sublayer framework + Google Gemini API
- **Database**: PostgreSQL + Sequel ORM + pgvector extension
- **UI**: TTY toolkit (prompts, tables, menus, progress bars)
- **Config**: TTY::Config for unified configuration management

### Database Schema
- `blueprints`: Core code storage with vector embeddings
- `categories`: Category definitions
- `blueprints_categories`: Many-to-many relationships

### Configuration System
Unified configuration management supporting:
- Multiple config sources (sublayer, blueprints, ruby_llm, logger)
- Environment variable mapping with `BLUEPRINTS_` prefix
- Validation rules and migration utilities
- Backward compatibility with legacy config files

## 🔧 Configuration Options

### AI Provider Settings
- **Sublayer Provider**: Gemini, OpenAI, Anthropic, DeepSeek
- **Embedding Model**: text-embedding-004 (768 dimensions)
- **Generation Model**: gemini-2.0-flash

### Database Configuration
- **URL**: PostgreSQL connection string
- **Connection Pool**: Configurable pool size
- **Batch Processing**: Configurable batch sizes

### Feature Flags
- **Auto Description**: AI-generated descriptions
- **Auto Categorization**: AI-powered category assignment
- **Improvement Analysis**: AI code analysis and suggestions
- **Semantic Search**: Vector-based search capabilities

### UI Preferences
- **Editor**: Preferred code editor
- **Colors**: Terminal color support
- **Interactive Mode**: Rich UI components
- **Pager**: Output pagination

## 🗺️ Roadmap

### Phase 1: Enhanced RAG Capabilities
Build a sophisticated Retrieval-Augmented Generation service that transforms the tool from a search engine into a collaborative coding partner:

**RAG Service Implementation**:
- **Retrieve**: Use semantic search to find 3-5 most relevant blueprints for user queries
- **Augment**: Format retrieved blueprints into structured context for LLM consumption
- **Generate**: Synthesize responses using generative LLM with expert developer prompts
- **Applications**: Answer complex questions, generate new code from patterns, provide step-by-step explanations

### Phase 2: Modern Deployment & Scalability
Leverage the lightweight Rack architecture for modern deployment patterns:

**Containerization**:
- Docker containerization with PostgreSQL services
- Kubernetes deployment manifests
- CI/CD pipeline integration

**Serverless Options**:
- AWS Lambda deployment (using lamby gem)
- Google Cloud Run compatibility
- Scale-to-zero cost optimization
- Database connection pooling for serverless

**Asynchronous Processing**:
- Background job integration (Sidekiq/Sucker Punch)
- Async embedding generation
- Batch processing capabilities
- Improved API responsiveness

### Phase 3: Advanced AI Features
Expand AI capabilities beyond search and categorization:

**Code Intelligence**:
- **Automated Code Review**: LLM-powered code analysis and improvement suggestions
- **Style Guide Enforcement**: Automated style and best practice checking
- **Bug Detection**: Pattern recognition for common coding issues
- **Performance Analysis**: Identification of performance bottlenecks

**Generative Features**:
- **Code Generation**: Natural language to code conversion
- **Pattern Synthesis**: Combine multiple blueprints into new solutions
- **Documentation Generation**: Automatic README and API documentation
- **Test Generation**: Automated test case creation

**Learning & Adaptation**:
- **Usage Analytics**: Track popular patterns and search queries
- **Recommendation Engine**: Suggest relevant blueprints based on context
- **Personal Learning**: Adapt to individual coding patterns and preferences

### Phase 4: Ecosystem Integration
Transform BlueprintsCLI into a comprehensive development ecosystem:

**IDE Integration**:
- VS Code extension for seamless blueprint access
- JetBrains plugin support
- Vim/Neovim integration
- Real-time code suggestion

**Team Collaboration**:
- Shared blueprint repositories
- Team-specific categorization
- Collaborative editing and review
- Blueprint versioning and history

**Package Ecosystem**:
- Community blueprint sharing
- Curated blueprint collections
- Import/export standards
- Blueprint marketplace

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes and add tests
4. Run the test suite: `bundle exec rspec`
5. Run linting: `bundle exec rubocop`
6. Commit your changes: `git commit -m 'Add amazing feature'`
7. Push to the branch: `git push origin feature/amazing-feature`
8. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- [Sublayer](https://github.com/sublayerapp/sublayer) - AI framework for Ruby
- [TTY Toolkit](https://ttytoolkit.org/) - Beautiful terminal applications
- [pgvector](https://github.com/pgvector/pgvector) - Vector similarity search for PostgreSQL
- [Google Gemini](https://ai.google.dev/) - AI models for embedding and generation