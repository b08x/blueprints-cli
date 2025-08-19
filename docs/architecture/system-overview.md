# BlueprintsCLI System Architecture

## Executive Summary

The blueprintsCLI project has been redesigned with a clean separation of concerns architecture, transitioning from a monolithic structure with mixed frontend/backend code to a modern microservices pattern. This architecture establishes dedicated services for frontend delivery, backend API operations, data persistence, and background processing, all orchestrated through Docker containers.

## Architecture Overview

The new architecture implements a microservices pattern with the following core services:

```
┌─────────────────┐    ┌──────────────────┐
│   API Gateway   │    │  Frontend Assets │
│     (Nginx)     │    │     (Nginx)      │
│   Port: 80/443  │    │   Port: 3000     │
└─────────┬───────┘    └──────────────────┘
          │                       │
          ├───────────────────────┴──────────────┐
          │                                      │
          ▼                                      │
┌─────────────────┐    ┌──────────────────┐    │
│  Backend API    │    │  Background Jobs │    │
│   (Ruby/Sinatra)│    │    (Sidekiq)     │    │
│   Port: 4000    │    │                  │    │
└─────────┬───────┘    └─────────┬────────┘    │
          │                      │              │
          ├──────────────────────┼──────────────┘
          │                      │
          ▼                      ▼
┌─────────────────┐    ┌──────────────────┐
│   PostgreSQL    │    │      Redis       │
│   (pgvector)    │    │ (Cache & Queue)  │
│   Port: 5432    │    │   Port: 6379     │
└─────────────────┘    └──────────────────┘
```

### Service Responsibilities

**API Gateway (Nginx)**
- Request routing and load balancing
- SSL termination and security headers
- Static asset caching
- Rate limiting and DDoS protection

**Frontend Service (Nginx)**
- Serve static web assets (HTML, CSS, JavaScript)
- Client-side routing support
- Asset compression and caching
- Completely decoupled from backend logic

**Backend API Service (Ruby/Sinatra)**
- Blueprint CRUD operations
- AI code generation integration
- Vector similarity search
- User session management
- Input validation and error handling

**Database Service (PostgreSQL + pgvector)**
- Blueprint and category data persistence
- Vector embeddings storage for similarity search
- ACID transaction support
- Full-text search capabilities

**Cache Service (Redis)**
- Session data storage
- API response caching
- Background job queue management
- Real-time data synchronization

**Background Processing (Sidekiq)**
- AI code generation tasks
- Vector embedding computation
- Batch data processing
- Email notifications and alerts

## Service Definitions

### Frontend Service
- **Technology**: Nginx static file server
- **Port**: Internal 3000 (exposed via API Gateway)
- **Dependencies**: None (fully decoupled)
- **Scaling**: Horizontal scaling with multiple static file servers
- **Health Check**: HTTP GET / returns 200

### Backend API Service
- **Technology**: Ruby 3.2+ with Sinatra framework
- **Port**: Internal 4000
- **Dependencies**: PostgreSQL, Redis
- **Key Features**: 
  - RESTful API with OpenAPI specification
  - CORS support for cross-origin requests
  - JSON request/response handling
  - Comprehensive error handling
  - Request logging and metrics
- **Scaling**: Horizontal scaling with load balancer
- **Health Check**: HTTP GET /api/health returns system status

### Database Service
- **Technology**: PostgreSQL 16 with pgvector extension
- **Port**: 5432
- **Features**:
  - ACID compliance for data integrity
  - Vector similarity search for blueprints
  - Full-text search capabilities
  - Automatic backup and recovery
- **Scaling**: Read replicas for query distribution
- **Health Check**: pg_isready command

### Cache & Queue Service
- **Technology**: Redis 7+ with RedisInsight management UI
- **Ports**: 6379 (Redis), 8081 (Management UI)
- **Features**:
  - In-memory data caching
  - Session persistence
  - Background job queue management
  - Pub/sub messaging
- **Scaling**: Redis cluster for high availability
- **Health Check**: Redis PING command

## Directory Structure Recommendations

```
blueprintsCLI/
├── backend/                     # Backend API service
│   ├── Dockerfile
│   ├── Gemfile
│   ├── Gemfile.lock
│   ├── config.ru
│   ├── app/
│   │   ├── models/             # Database models
│   │   ├── services/           # Business logic services
│   │   ├── controllers/        # API controllers
│   │   └── middleware/         # Custom middleware
│   ├── config/
│   │   ├── database.rb
│   │   ├── redis.rb
│   │   └── sidekiq.rb
│   ├── db/
│   │   ├── migrations/         # Database migrations
│   │   └── seeds/              # Seed data
│   ├── lib/                    # Shared libraries
│   ├── spec/                   # Test specifications
│   └── logs/                   # Application logs
│
├── frontend/                   # Frontend service
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── src/
│   │   ├── assets/
│   │   │   ├── css/
│   │   │   ├── js/
│   │   │   └── images/
│   │   ├── components/         # Reusable UI components
│   │   ├── pages/              # Individual pages
│   │   └── utils/              # Frontend utilities
│   ├── dist/                   # Built assets
│   └── public/                 # Static files
│
├── nginx/                      # API Gateway configuration
│   ├── nginx.conf
│   ├── conf.d/
│   │   ├── api.conf
│   │   └── frontend.conf
│   └── ssl/                    # SSL certificates
│
├── docker/                     # Docker configurations
│   ├── docker-compose.yml
│   ├── docker-compose.dev.yml
│   ├── docker-compose.prod.yml
│   └── init-scripts/
│       └── 01-init-pgvector.sql
│
├── docs/                       # Documentation
│   ├── architecture/
│   ├── api/
│   └── deployment/
│
└── scripts/                    # Utility scripts
    ├── setup.sh
    ├── deploy.sh
    └── backup.sh
```

## Development and Production Considerations

### Development Workflow

1. **Local Development Setup**:
   ```bash
   # Clone and setup
   git clone <repository>
   cd blueprintsCLI
   
   # Start development environment
   docker-compose -f docker/docker-compose.dev.yml up
   
   # Backend available at: http://localhost:4000
   # Frontend available at: http://localhost:3000
   # Database available at: localhost:5432
   # Redis available at: localhost:6379
   ```

2. **Hot Reloading**:
   - Backend: Volume mount source code for live reloading
   - Frontend: Development server with hot module replacement
   - Database: Persistent volumes for data retention

3. **Testing Strategy**:
   - Unit tests for individual service components
   - Integration tests for API endpoints
   - End-to-end tests for complete workflows
   - Performance tests for scalability validation

### Production Deployment

1. **Environment Configuration**:
   - Environment-specific docker-compose files
   - Secret management through environment variables
   - SSL certificate configuration
   - Database connection pooling

2. **Scaling Strategy**:
   - Horizontal scaling of backend API containers
   - Database read replicas for query distribution
   - Redis cluster for cache distribution
   - Load balancer health checks and failover

3. **Monitoring and Observability**:
   - Application performance monitoring
   - Infrastructure metrics collection
   - Centralized logging with log aggregation
   - Error tracking and alerting
   - Database performance monitoring

### Security Considerations

1. **Network Security**:
   - Private Docker networks for service communication
   - API Gateway as single entry point
   - Internal service communication over encrypted channels
   - Database access restricted to backend services only

2. **Application Security**:
   - Input validation and sanitization
   - SQL injection prevention through ORM
   - CORS policy configuration
   - Rate limiting and DDoS protection
   - Secrets management and environment isolation

3. **Data Security**:
   - Database encryption at rest
   - Secure backup and recovery procedures
   - User data privacy compliance
   - Audit logging for sensitive operations

This architecture provides a solid foundation for scalable, maintainable, and secure application development while maintaining clear separation of concerns and enabling independent service development and deployment.