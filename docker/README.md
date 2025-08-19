# BlueprintsCLI Docker Setup

This directory contains the complete Docker configuration for the BlueprintsCLI application, organized for both development and production environments.

## 🏗️ Architecture

The application runs as a microservices architecture with the following components:

- **Frontend**: Static web assets served by Nginx
- **Backend**: Ruby/Sinatra API service  
- **Database**: PostgreSQL with pgvector extension
- **Cache**: Redis for caching and session storage
- **Reverse Proxy**: Nginx for load balancing and SSL termination

## 📁 Directory Structure

```
docker/
├── docker-compose.yml              # Production environment
├── docker-compose.dev.yml          # Development environment  
├── docker-compose.override.yml     # Local customizations (gitignored)
├── .env.example                    # Environment template
├── .env                           # Local environment (gitignored)
├── configs/
│   ├── nginx/
│   │   ├── production.conf        # Production Nginx config
│   │   └── development.conf       # Development Nginx config
│   └── postgres/
│       └── init-scripts/          # Database initialization
└── README.md                      # This file
```

## 🚀 Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- At least 4GB RAM available
- Ports 3000, 5432, 6379, 8080 available (development)
- Ports 80, 443, 5432, 6379 available (production)

### Development Setup

1. **Setup environment variables:**
   ```bash
   rake docker:setup_env
   # Edit docker/.env with your values
   ```

2. **Start development environment:**
   ```bash
   rake docker:dev:up
   # Or with additional tools:
   rake docker:dev:up PROFILES=with-adminer,with-mail
   ```

3. **Access services:**
   - 🌐 Frontend: http://localhost:8080
   - 🔧 Backend API: http://localhost:3000/api
   - 🗄️ Database: localhost:5433 (postgres/dev_password)
   - 📊 Adminer: http://localhost:8081 (if using `with-adminer` profile)
   - 📧 MailCatcher: http://localhost:1080 (if using `with-mail` profile)

### Production Deployment

1. **Setup environment variables:**
   ```bash
   cp docker/.env.example docker/.env
   # Edit docker/.env with production values
   ```

2. **Deploy with health checks:**
   ```bash
   rake docker:prod:deploy
   ```

3. **Access application:**
   - 🌐 Application: http://localhost

## 🛠️ Development Workflow

### Common Commands

```bash
# Environment management
rake docker:dev:up              # Start development
rake docker:dev:down            # Stop development
rake docker:dev:restart         # Restart development
rake docker:dev:logs            # View logs
rake docker:dev:shell           # Backend shell
rake docker:dev:db_shell        # PostgreSQL shell
rake docker:dev:redis_cli       # Redis CLI

# Database operations
rake docker:db:migrate          # Run migrations
rake docker:db:seed             # Seed database
rake docker:db:reset            # Reset dev database

# Utilities
rake docker:build               # Build images
rake docker:health              # Check service health
rake docker:ps                  # Show containers
rake docker:stats               # Resource usage
```

### Hot Reloading

Development environment includes hot reloading:

- **Backend**: Code changes trigger automatic restart via `rerun`
- **Frontend**: Static files are mounted as volumes for instant updates
- **Database**: Schema changes require `rake docker:db:migrate`

### Debugging

Access container shells for debugging:

```bash
# Backend container shell
rake docker:dev:shell

# Database shell
rake docker:dev:db_shell

# View logs
rake docker:dev:logs
rake docker:dev:logs SERVICE=backend-dev
```

## 🚀 Production Considerations

### Security

- Change all default passwords in `.env`
- Configure SSL certificates in nginx configuration
- Use strong JWT and session secrets
- Enable firewall rules for exposed ports
- Regular security updates for base images

### Performance

- Resource limits configured in compose files
- Nginx optimized for high concurrency
- PostgreSQL tuned for production workloads  
- Redis configured with memory limits
- Gzip compression enabled

### Monitoring

- Health checks for all services
- Structured logging with JSON format
- Resource usage monitoring via `docker:stats`
- Application metrics via `/health` endpoints

### Backup & Recovery

```bash
# Create database backup
rake docker:db:backup

# Restore from backup
rake docker:db:restore BACKUP_FILE=path/to/backup.sql
```

## 🔧 Customization

### Environment Variables

See `.env.example` for all available configuration options:

- Database settings
- Application secrets
- Port mappings
- Resource limits
- Feature flags

### Local Overrides

Use `docker-compose.override.yml` for local customizations:

```yaml
# docker/docker-compose.override.yml
services:
  backend-dev:
    environment:
      - DEBUG=true
    ports:
      - "9229:9229"  # Debug port
```

### Adding Services

To add new services:

1. Define service in appropriate compose file
2. Add health checks and logging configuration
3. Update Rake tasks if needed
4. Document service in this README

## 🧪 Testing

```bash
# Run tests in containers
rake docker:test:run

# Setup test environment
rake docker:test:setup

# Cleanup test resources
rake docker:test:clean
```

## 📊 Service Profiles

Development environment supports optional service profiles:

- `with-adminer`: Database admin interface
- `with-mail`: Email testing with MailCatcher  
- `with-proxy`: Nginx reverse proxy for production-like routing

Example:
```bash
rake docker:dev:up PROFILES=with-adminer,with-mail
```

## 🛟 Troubleshooting

### Common Issues

1. **Port conflicts:**
   ```bash
   # Check what's using ports
   netstat -tlnp | grep :3000
   # Modify ports in .env file
   ```

2. **Permission issues:**
   ```bash
   # Fix volume permissions
   sudo chown -R $USER:$USER docker/data
   ```

3. **Database connection issues:**
   ```bash
   # Check database health
   rake docker:health
   # Reset development database
   rake docker:db:reset
   ```

4. **Memory issues:**
   ```bash
   # Check resource usage
   rake docker:stats
   # Increase Docker memory limits
   ```

### Log Analysis

```bash
# All logs
rake docker:dev:logs

# Specific service logs
rake docker:dev:logs SERVICE=backend-dev

# Follow logs in real-time
docker compose -f docker/docker-compose.dev.yml logs -f
```

### Clean Reset

```bash
# Stop everything
rake docker:dev:down

# Remove volumes and images
rake docker:clean

# Start fresh
rake docker:dev:up
```

## 📚 Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Nginx Configuration Guide](https://nginx.org/en/docs/)
- [PostgreSQL Docker Guide](https://hub.docker.com/_/postgres)
- [Redis Docker Guide](https://hub.docker.com/_/redis)

## 🤝 Contributing

When modifying Docker configurations:

1. Test changes in development environment
2. Update documentation
3. Verify production deployment
4. Add appropriate Rake tasks
5. Update this README