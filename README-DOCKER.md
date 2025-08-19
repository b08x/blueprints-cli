# Dockerized BlueprintsCLI Architecture

## Overview

The BlueprintsCLI application has been restructured into a microservices architecture with proper separation of concerns:

- **Frontend**: Static web assets served by Nginx
- **Backend**: Ruby API-only service  
- **Database**: PostgreSQL with pgvector extension
- **Cache**: Redis for caching and background jobs
- **Reverse Proxy**: Nginx for routing and load balancing

## Quick Start

The Docker configuration has been completely reorganized for better maintainability. All Docker components are now in the `docker/` directory with comprehensive Rake task management.

### Development Environment
```bash
# Setup environment
rake docker:setup_env

# Start development with hot-reload
rake docker:dev:up

# Start with admin tools
rake docker:dev:up PROFILES=with-adminer,with-mail
```

### Production Environment
```bash
# Deploy production
rake docker:prod:deploy
```

## New Directory Structure

```
docker/                          # ← NEW: Organized Docker configuration
├── docker-compose.yml          # Production environment
├── docker-compose.dev.yml      # Development environment  
├── docker-compose.override.yml # Local customizations
├── .env.example                # Environment template
├── configs/
│   ├── nginx/
│   │   ├── production.conf     # Production Nginx config
│   │   └── development.conf    # Development Nginx config
│   └── postgres/
│       └── init-scripts/       # Database initialization
└── README.md                   # Comprehensive Docker guide

frontend/                        # Frontend service
├── pages/                      # HTML pages
├── public/                     # CSS, JS, and static assets
├── nginx.conf                  # (deprecated - moved to docker/configs/)
└── Dockerfile                  # Frontend container

backend/                         # Backend API service
├── lib/                        # API application code
├── config.ru                   # Rack configuration
├── Gemfile                     # Ruby dependencies
├── Dockerfile                  # Production container
└── Dockerfile.dev              # Development container

lib/                            # Original BlueprintsCLI code (mounted in backend)
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
- **Frontend**: Live volume mounts for instant updates
- **Debug Access**: Ruby debug port exposed (9229)
- **Database Tools**: Adminer web interface available
- **Email Testing**: MailCatcher for development emails

### Service Profiles
Development environment supports optional profiles:
- `with-adminer`: Database admin interface at http://localhost:8081
- `with-mail`: Email testing at http://localhost:1080
- `with-proxy`: Nginx reverse proxy testing

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

### From Old Setup
- **Centralized Configuration**: All Docker files in one place
- **Consistent Environments**: Standardized dev/prod configurations
- **Task Automation**: Comprehensive Rake task coverage
- **Better Documentation**: Detailed setup and troubleshooting guides
- **Improved Performance**: Optimized configurations for both environments

### Preserved Features
- **No Code Changes**: All existing functionality preserved
- **Backward Compatibility**: Original `lib/blueprintsCLI/` code mounted
- **Same API Endpoints**: All existing endpoints still available
- **Data Persistence**: Database and Redis data preserved across updates

## What's New

1. **Organized Structure**: Clean separation of Docker components
2. **Comprehensive Rake Tasks**: 30+ tasks for Docker management
3. **Environment Management**: Proper `.env` handling and validation
4. **Production Optimizations**: Security, performance, and monitoring
5. **Development Tools**: Adminer, MailCatcher, debug access
6. **Documentation**: Detailed guides in `docker/README.md`

## Next Steps

See `docker/README.md` for:
- Detailed setup instructions
- Troubleshooting guide
- Customization options
- Security considerations
- Performance tuning
- Monitoring setup