# BlueprintsCLI: AI-Powered Code Blueprint System

BlueprintsCLI is an intelligent code management and generation tool built on the **Sublayer AI Agent framework**. It transforms how you store, organize, and generate code by combining semantic search with AI-powered code generation, creating a personalized code blueprint library that learns from your patterns and generates contextually relevant code.

**Powered by Sublayer**: BlueprintsCLI leverages Sublayer's modular architecture with AI Actions, Generators, and Agents to create an intelligent, autonomous code management system that adapts to your development workflow.

## 🎯 What Makes BlueprintsCLI Different

Unlike traditional snippet managers, BlueprintsCLI:

- **Learns from your code patterns** - AI analyzes and categorizes your blueprints automatically
- **Generates contextual code** - Uses your existing blueprints as context for new code generation
- **Semantic search** - Find blueprints by meaning, not just keywords
- **AI-enhanced metadata** - Automatically generates names, descriptions, and categories
- **Language agnostic** - Supports 25+ programming languages and file types

## 🚀 Core Workflow: From Code to Blueprint to Generation

### 1. Submit Code Blueprints

Turn any code into a searchable, AI-enhanced blueprint:

```bash
# Submit from file
bin/blueprintsCLI blueprint submit path/to/my_script.rb

# Submit directly
bin/blueprintsCLI blueprint submit "
def fibonacci(n)
  return n if n <= 1
  fibonacci(n-1) + fibonacci(n-2)
end
"
```

**What happens automatically:**

- 🤖 AI generates a descriptive name
- 📝 Creates detailed description from code analysis  
- 🏷️ Assigns relevant categories
- 🔍 Generates 768-dimensional vector embeddings for semantic search
- 🎯 Detects language, file type, and blueprint patterns

### 2. Discover with Semantic Search

Find blueprints using natural language:

```bash
# Find by functionality
bin/blueprintsCLI blueprint search "recursive algorithm fibonacci"

# Find by technology
bin/blueprintsCLI blueprint search "web server sinatra ruby"

# Find by pattern
bin/blueprintsCLI blueprint search "database connection pooling"
```

### 3. Generate New Code from Blueprints

Use your blueprint library to generate new code:

```bash
# Generate with natural language prompt
bin/blueprintsCLI generate --prompt "Create a Ruby web API with authentication using my existing patterns"

# Specify output directory
bin/blueprintsCLI generate --prompt "Build a calculator class" --output ./generated

# Control context size
bin/blueprintsCLI generate --prompt "Create tests for user model" --limit 10
```

**Generation Process:**

1. **Context Discovery** - Searches your blueprints for relevant patterns
2. **AI Generation** - Uses Google Gemini with your blueprints as context
3. **Multi-file Output** - Creates structured project files
4. **Pattern Matching** - Applies your coding style and conventions

## 🎛️ Interactive vs. Direct Usage

### Interactive Menu System

Launch the guided interface:

```bash
bin/blueprintsCLI
```

Features:

- Step-by-step blueprint submission
- Guided search and discovery
- Interactive code generation workflow
- Real-time preview and editing

### Direct CLI Commands

For scripting and automation:

```bash
bin/blueprintsCLI blueprint submit code.rb
bin/blueprintsCLI blueprint search "authentication"
bin/blueprintsCLI generate --prompt "API client"
```

## 🧠 AI-Powered Features

### Sublayer Framework Integration

BlueprintsCLI's AI capabilities are powered by Sublayer's modular components:

#### Intelligent Actions

- **Submit Action**: Auto-generates metadata using AI Generators
- **Generate Action**: Orchestrates code creation with blueprint context
- **Search Action**: Performs semantic search with vector similarity

#### Specialized Generators  

- **Description Generator**: Creates clear, developer-focused explanations
- **Name Generator**: Produces meaningful names from code analysis
- **Category Generator**: Automatically assigns relevant tags
- **Improvement Generator**: Suggests code enhancements

#### Future Agent Capabilities

- **File Monitoring**: Detect and update blueprints on code changes
- **Quality Assurance**: Continuous code improvement suggestions
- **Test Integration**: Automated testing of generated code

### Automatic Metadata Generation

- **Smart Naming**: Generates meaningful names from code analysis
- **Rich Descriptions**: Creates detailed explanations of functionality
- **Category Assignment**: Automatically tags with relevant categories
- **Type Detection**: Identifies language, framework, and architectural patterns

### Context-Aware Code Generation

- **Pattern Recognition**: Learns from your existing code style
- **Technology Consistency**: Uses frameworks and libraries from your blueprints
- **Architectural Alignment**: Follows your project structure patterns
- **Best Practices**: Incorporates security and performance patterns from your code

### Vector-Based Similarity Search

- Uses Google's text-embedding-004 model
- 768-dimensional vector space for precise matching
- Semantic understanding beyond keyword matching
- Distance-based relevance scoring

## 📊 Blueprint Categories and Organization

Blueprints are automatically organized by:

- **Functionality**: algorithms, data structures, utilities
- **Technology**: frameworks, libraries, APIs
- **Architecture**: patterns, designs, components  
- **Domain**: web, mobile, data, system administration
- **Language**: ruby, python, javascript, etc.

## 🎨 Code Generation Examples

### Web API Generation

```bash
bin/blueprintsCLI generate --prompt "Create a REST API for user management with JWT authentication"
```

**Output**: Multi-file project with routes, models, middleware, and tests

### Algorithm Implementation

```bash
bin/blueprintsCLI generate --prompt "Implement a binary search tree with traversal methods"
```

**Output**: Complete class with insertion, deletion, and traversal algorithms

### Data Processing Pipeline

```bash
bin/blueprintsCLI generate --prompt "Build a CSV processor with validation and transformation"
```

**Output**: Modular pipeline with error handling and logging

## 🔧 Advanced Blueprint Management

### Viewing and Analysis

```bash
# View blueprint with AI analysis
bin/blueprintsCLI blueprint view 42 --analyze

# Export blueprint code
bin/blueprintsCLI blueprint export 42 output.rb

# Edit blueprint metadata
bin/blueprintsCLI blueprint edit 42
```

### Batch Operations

```bash
# List with filtering
bin/blueprintsCLI blueprint list --format json | jq '.[] | select(.language == "ruby")'

# Search with limits
bin/blueprintsCLI blueprint search "database" --limit 20
```

## 🛠️ Setup and Configuration

### Requirements

- Ruby 3.1+
- PostgreSQL with pgvector extension
- Google Gemini API key

### Quick Start

```bash
# Clone and install
git clone <repository-url>
cd blueprintsCLI
bundle install

# Database setup
rake db:create
rake db:migrate

# Configuration
bin/blueprintsCLI config setup
export GEMINI_API_KEY="your-api-key"

# First blueprint
bin/blueprintsCLI blueprint submit "puts 'Hello, BlueprintsCLI!'"
```

### Configuration Options

```yaml
# ~/.config/BlueprintsCLI/config.yml
ai:
  provider: gemini
  model: gemini-2.0-flash
  
database:
  url: postgresql://postgres:password@localhost:5432/blueprints
  
generation:
  default_output_dir: ./generated
  default_limit: 5
```

## 📈 Supported Languages and Technologies

**Languages (25+)**:
Ruby, Python, JavaScript, TypeScript, Java, Go, Rust, C++, C#, PHP, Swift, Kotlin, Scala, Clojure, Haskell, and more

**File Types**:
Source code, configuration files, documentation, scripts, templates, schemas

**Frameworks Detected**:
Rails, Sinatra, Flask, Django, React, Vue, Express, Spring, and many others

## 🎯 Use Cases

### Personal Code Library

- Store and organize your utility functions
- Build a searchable knowledge base of solutions
- Generate variations of your proven patterns

### Team Knowledge Sharing

- Centralize team coding patterns and best practices
- Accelerate onboarding with contextual code examples
- Maintain consistency across projects

### Rapid Prototyping

- Generate boilerplate code from natural language
- Combine existing patterns into new solutions
- Iterate quickly with AI-assisted development

### Learning and Education

- Analyze code patterns and improvements
- Generate examples for specific concepts
- Build understanding through contextual exploration

## 🔍 Architecture and Technology

### Built on Sublayer Framework

BlueprintsCLI is architected using the [Sublayer](https://github.com/sublayerapp/sublayer) framework, a model-agnostic Ruby AI Agent framework that provides modular, intelligent components:

#### 🎭 Actions (`Sublayer::Actions::Base`)

Actions perform specific operations and handle business logic without complex decision-making:

- **`Submit`** - Processes blueprint submission with AI-enhanced metadata generation
- **`Generate`** - Orchestrates code generation using existing blueprints as context
- **`Search`** - Handles semantic search queries with vector similarity
- **`View`** - Displays blueprints with optional AI analysis
- **`Config`** - Manages configuration setup and validation

Example Action implementation:

```ruby
class Submit < Sublayer::Actions::Base
  def call
    generate_missing_metadata    # AI-powered name/description generation
    validate_blueprint_data     # Data validation
    create_blueprint           # Database persistence
  end
end
```

#### 🏭 Generators (`Sublayer::Generators::Base`)

Generators focus on single AI generation tasks, producing specific outputs:

- **`Description`** - Generates clear, developer-focused code descriptions
- **`Name`** - Creates meaningful blueprint names from code analysis
- **`Category`** - Automatically assigns relevant categories
- **`Improvement`** - Suggests code enhancements and optimizations

Example Generator implementation:

```ruby
class Description < Sublayer::Generators::Base
  llm_output_adapter type: :single_string,
                     name: 'description',
                     description: 'Clear, concise code functionality description'
                     
  def prompt
    "Analyze this #{@language} code and provide a clear description: #{@code}"
  end
end
```

#### 🤖 Agents (`Sublayer::Agents::Base`)

Autonomous entities for monitoring and automated tasks (extensible for future features):

- **File change monitoring** - Automatically update blueprints when source files change
- **Test integration** - Run tests on generated code and suggest improvements
- **Code quality** - Monitor and suggest blueprint improvements

#### 🔄 Model-Agnostic AI Integration

Sublayer's flexible provider system supports multiple AI models:

- **Google Gemini** (default) - `gemini-2.0-flash` for generation, `text-embedding-004` for embeddings
- **OpenAI** - GPT models with text-embedding-3-small
- **Claude** - Anthropic's models for advanced reasoning
- **Local models** - Via Ollama integration

Configuration example:

```yaml
ai:
  sublayer:
    provider: gemini
    model: gemini-2.0-flash
  embedding_model: text-embedding-004
```

### Additional Technology Stack

- **CLI Framework**: Thor with dynamic command discovery
- **Database**: PostgreSQL with pgvector for vector similarity
- **Search**: 768-dimensional semantic vector space
- **UI**: TTY toolkit for rich terminal interfaces  
- **Configuration**: TTY::Config with environment variable mapping
- **AI Integration**: Dual-layer with Sublayer + RubyLLM for maximum flexibility

## 🚀 Development and Testing

```bash
# Run tests
bundle exec rspec

# Code quality
bundle exec rubocop

# Documentation
bundle exec yard doc

# Interactive console
bundle exec pry
```

### Extending with Sublayer Components

BlueprintsCLI's Sublayer architecture makes it easy to add new AI-powered features:

#### Creating Custom Generators

```ruby
class CustomGenerator < Sublayer::Generators::Base
  llm_output_adapter type: :single_string,
                     name: 'output',
                     description: 'Generated content'
                     
  def initialize(input:)
    @input = input
  end
  
  def prompt
    "Process this input: #{@input}"
  end
end
```

#### Adding New Actions

```ruby
class CustomAction < Sublayer::Actions::Base
  def initialize(params)
    @params = params
  end
  
  def call
    # Use generators and perform operations
    result = CustomGenerator.new(input: @params[:input]).generate
    # Process result...
  end
end
```

#### Building Autonomous Agents

```ruby
class MonitoringAgent < Sublayer::Agents::Base
  trigger_on_files_changed { ["**/*.rb"] }
  
  goal_condition { @analysis_complete }
  
  step do
    # Analyze changed files
    # Update relevant blueprints
    # Set @analysis_complete = true
  end
end
```

## 📖 Documentation Generation

Generate AI-powered YARD documentation:

```bash
bin/blueprintsCLI docs generate lib/my_class.rb
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Make changes and add tests
4. Run test suite: `bundle exec rspec`
5. Submit pull request

## 📄 License

MIT License - see LICENSE file for details

---

**Start building your intelligent code blueprint library today!**

```bash
bin/blueprintsCLI
```
