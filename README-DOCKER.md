# Dockerized BlueprintsCLI Architecture

## Overview

The BlueprintsCLI application is containerized as a Ruby gem-based application with supporting services:

- **Backend**: Ruby CLI/API application built from gemspec
- **Database**: PostgreSQL with pgvector extension
- **Cache**: Redis for caching and background jobs

## Quick Start

The Docker configuration has been completely reorganized for better maintainability. All Docker components are now in the `docker/` directory with comprehensive Rake task management.

### Development Environment
```bash
# Setup environment
rake docker:setup_env

# Start development with hot-reload
rake docker:dev:up

# Start with database admin tools
rake docker:dev:up PROFILES=with-adminer
```

### Production Environment
```bash
# Deploy production
rake docker:prod:deploy
```

## New Directory Structure

```
docker/                          # ← Organized Docker configuration
├── docker-compose.yml          # Production environment
├── docker-compose.dev.yml      # Development environment  
├── docker-compose.override.yml # Local customizations
├── .env.example                # Environment template
├── Dockerfile                  # Production Ruby app container
├── Dockerfile.dev              # Development Ruby app container
├── configs/
│   └── postgres/
│       └── init-scripts/       # Database initialization
└── README.md                   # Comprehensive Docker guide

lib/                            # BlueprintsCLI gem source code
├── blueprintsCLI/             # Main application modules
└── BlueprintsCLI.rb           # Main entry point

Gemfile                         # Ruby dependencies
Gemfile.lock                   # Locked gem versions
blueprintsCLI.gemspec          # Gem specification
```

## Comprehensive Rake Task Management

The new setup includes extensive Rake tasks for Docker management:

### Development Tasks
```bash
rake docker:dev:up              # Start development environment
rake docker:dev:down            # Stop development environment
rake docker:dev:restart         # Restart development environment
rake docker:dev:logs            # Show development logs
rake docker:dev:shell           # Open shell in backend container
rake docker:dev:db_shell        # Open psql shell
rake docker:dev:redis_cli       # Open redis-cli

# Convenience aliases
rake dev:up                     # → docker:dev:up
rake dev:down                   # → docker:dev:down
```

### Production Tasks
```bash
rake docker:prod:up             # Start production environment
rake docker:prod:down           # Stop production environment
rake docker:prod:deploy         # Deploy with health checks
rake docker:prod:logs           # Show production logs

# Convenience aliases  
rake prod:up                    # → docker:prod:up
rake prod:down                  # → docker:prod:down
```

### Database Management
```bash
rake docker:db:backup           # Backup database
rake docker:db:restore          # Restore database from backup
rake docker:db:reset            # Reset development database
rake docker:db:migrate          # Run migrations in container
rake docker:db:seed             # Seed database in container
```

### Utility Tasks
```bash
rake docker:build               # Build all images
rake docker:build:force         # Force rebuild all images
rake docker:clean               # Clean unused images/volumes
rake docker:ps                  # Show running containers
rake docker:health              # Check service health
rake docker:stats               # Show container resource usage
rake docker:help                # Show all available tasks
```

## Enhanced Development Experience

### Hot Reloading & Debugging
- **Backend**: Automatic restart on code changes via `rerun`
- **Code Volumes**: Live volume mounts for instant updates
- **Debug Access**: Ruby debug port exposed (9229)
- **Database Tools**: Adminer web interface available

### Service Profiles
Development environment supports optional profiles:
- `with-adminer`: Database admin interface at http://localhost:8081

### Environment Configuration
- **Template**: `docker/.env.example` with all options documented
- **Validation**: `rake docker:check_env` validates required variables
- **Overrides**: `docker-compose.override.yml` for local customizations

## Production Ready Features

### Security & Performance
- **Security Headers**: Comprehensive security headers in Nginx
- **Rate Limiting**: API and static content rate limiting
- **Resource Limits**: Memory and CPU limits for all services
- **Health Checks**: All services have health monitoring
- **SSL Ready**: SSL configuration prepared (needs certificates)

### Monitoring & Observability
- **Structured Logging**: JSON logging with request tracing
- **Health Endpoints**: `/health` and `/nginx-health` endpoints
- **Resource Monitoring**: Real-time container stats via Rake tasks
- **Log Aggregation**: Centralized logging configuration

### Backup & Recovery
- **Automated Backups**: `rake docker:db:backup` with timestamps
- **Point-in-time Recovery**: Restore from any backup
- **Volume Management**: Persistent data with proper permissions

## Migration Benefits

### Key Improvements
- **Gem-based Build**: Proper bundle install using gemspec
- **Security**: Non-root user implementation
- **Simplicity**: Focused on essential services only
- **Performance**: Optimized layer caching and build process
- **Development**: Hot-reloading with volume mounts

### Preserved Features
- **No Code Changes**: All existing CLI functionality preserved
- **Gem Structure**: Standard Ruby gem layout maintained
- **Database Integration**: PostgreSQL with pgvector support
- **Data Persistence**: Database and Redis data preserved across updates

## What's New

1. **Simplified Architecture**: Focus on Ruby gem with essential services
2. **Proper Gem Build**: Uses gemspec for correct dependency management
3. **Security First**: Non-root containers and proper user permissions
4. **Development Optimized**: Hot-reloading and debugging support
5. **Clean Structure**: Removed unnecessary frontend/nginx complexity
6. **Production Ready**: Efficient multi-stage builds with health checks

## Next Steps

See `docker/README.md` for:
- Detailed setup instructions
- Troubleshooting guide
- Customization options
- Security considerations
- Performance tuning
- Monitoring setup