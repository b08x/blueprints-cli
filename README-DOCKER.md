# Dockerized BlueprintsCLI Architecture

## Overview

The BlueprintsCLI application is containerized as a modern web application with comprehensive services:

- **Frontend**: React-style SPA with nginx serving and API proxy
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
├── .env.example                # Backend environment template
├── .env.frontend.example       # Frontend environment template
├── Dockerfile                  # Production Ruby app container
├── Dockerfile.dev              # Development Ruby app container
├── configs/
│   └── postgres/
│       └── init-scripts/       # Database initialization
└── README.md                   # Comprehensive Docker guide

frontend/                       # Frontend web application
├── Dockerfile.production       # Production frontend container
├── Dockerfile.dev              # Development frontend container
├── nginx.production.conf       # Production nginx configuration
├── nginx.development.conf      # Development nginx configuration
├── nginx.security.conf         # Security headers configuration
├── pages/                      # HTML pages and assets
├── public/                     # Static public assets
└── src/                        # Source files

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
rake docker:dev:up              # Start development environment (backend + frontend)
rake docker:dev:down            # Stop development environment
rake docker:dev:restart         # Restart development environment
rake docker:dev:logs            # Show development logs (all services)
rake docker:dev:shell           # Open shell in backend container
rake docker:dev:frontend_shell  # Open shell in frontend container
rake docker:dev:db_shell        # Open psql shell
rake docker:dev:redis_cli       # Open redis-cli

# Individual service management
rake docker:dev:frontend_up     # Start only frontend development service
rake docker:dev:backend_up      # Start only backend development service

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
- **Frontend**: Live reload via nginx volume mounts for instant HTML/CSS/JS updates
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
- **Security Headers**: Comprehensive security headers in frontend nginx
- **Rate Limiting**: API and static content rate limiting
- **Resource Limits**: Memory and CPU limits for all services
- **Health Checks**: All services have health monitoring
- **SSL Ready**: SSL configuration prepared (needs certificates)
- **API Proxy**: Frontend nginx proxies API requests to backend with CORS support
- **Asset Optimization**: Gzip compression and caching for static assets

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
- **Complete Web Stack**: Frontend + backend + database integration
- **Gem-based Build**: Proper bundle install using gemspec
- **Security**: Non-root user implementation for all services
- **Performance**: Optimized layer caching and multi-stage builds
- **Development**: Hot-reloading with volume mounts for both frontend and backend
- **API Integration**: Seamless frontend-backend communication via nginx proxy

### Preserved Features
- **No Code Changes**: All existing CLI functionality preserved
- **Gem Structure**: Standard Ruby gem layout maintained
- **Database Integration**: PostgreSQL with pgvector support
- **Data Persistence**: Database and Redis data preserved across updates

## What's New

1. **Complete Web Application**: Full-stack deployment with frontend, backend, and database
2. **Modern Frontend**: SPA with nginx serving, API proxy, and production optimizations
3. **Security First**: Non-root containers, security headers, and rate limiting
4. **Development Optimized**: Hot-reloading for both frontend and backend
5. **Production Ready**: Multi-stage builds, health checks, and resource limits
6. **API Integration**: Seamless frontend-backend communication with CORS support

## Service Access

After starting the services, you can access:

### Production Environment
```bash
rake docker:prod:up
```
- **Frontend Web UI**: http://localhost:8080
- **Backend API**: http://localhost:3000/api
- **Database**: localhost:5432 (postgres/blueprints)
- **Redis**: localhost:6379

### Development Environment
```bash
rake docker:dev:up
```
- **Frontend Web UI**: http://localhost:8080 (with hot reload)
- **Backend API**: http://localhost:3000/api (with debug support)
- **Database**: localhost:5433 (postgres/dev_password)
- **Redis**: localhost:6380
- **Adminer**: http://localhost:8081 (with --profile with-adminer)

### Frontend Features
The frontend provides a modern web interface for:
- **Blueprint Search**: Search through existing code templates
- **Code Generation**: Generate new code using AI assistance
- **Blueprint Submission**: Submit new blueprints to the system
- **Blueprint Viewing**: Browse and examine blueprint details

## Next Steps

See `docker/README.md` for:
- Detailed setup instructions
- Troubleshooting guide
- Customization options
- Security considerations
- Performance tuning
- Monitoring setup