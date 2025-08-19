# Service Separation Strategy

## Overview

This document outlines the comprehensive strategy for separating the BlueprintsCLI application from a monolithic structure with mixed concerns into a clean, scalable microservices architecture. The separation addresses the critical issues of maintainability, scalability, and development workflow efficiency.

## Current Architecture Problems

### Mixed Concerns Issues Identified

1. **Frontend-Backend Coupling**: HTML, CSS, and JavaScript files are embedded within the Ruby backend codebase at `lib/blueprintsCLI/public/`
2. **Single Responsibility Violation**: The Rack application serves both API endpoints and static files
3. **Development Complexity**: Changes to frontend require backend service restarts
4. **Deployment Coupling**: Frontend and backend must be deployed together
5. **Scaling Limitations**: Cannot scale frontend and backend independently
6. **Technology Constraints**: Frontend is limited to backend deployment environment

### Existing File Structure Analysis

```
lib/blueprintsCLI/
├── config.ru              # Rack application (API + static files)
├── web_app.rb             # Sinatra application (API + static files)
├── public/                # Frontend assets mixed with backend
│   ├── css/app.css
│   ├── js/{app.js, viewer.js, index.js}
│   ├── {index, generator, submission, viewer}.html
└── services/              # Backend business logic
```

**Problems with Current Structure**:
- Static files served through Ruby application server (performance penalty)
- Frontend development requires Ruby environment setup
- No separation of development workflows
- Single deployment artifact for different concerns

## Service Separation Architecture

### Proposed Directory Structure

```
blueprintsCLI/
├── backend/                        # Ruby API Service
│   ├── Dockerfile
│   ├── Dockerfile.dev
│   ├── Gemfile
│   ├── config.ru
│   ├── app/
│   │   ├── controllers/           # API endpoints
│   │   ├── models/               # Database models
│   │   ├── services/             # Business logic
│   │   └── middleware/           # Custom middleware
│   ├── config/
│   │   ├── database.rb           # Database configuration
│   │   ├── redis.rb              # Redis configuration
│   │   └── sidekiq.rb            # Background jobs
│   ├── db/
│   │   ├── migrations/           # Database schema changes
│   │   └── seeds/                # Sample data
│   └── spec/                     # Backend tests
│
├── frontend/                       # Frontend Service
│   ├── Dockerfile
│   ├── Dockerfile.dev
│   ├── package.json
│   ├── src/
│   │   ├── assets/
│   │   │   ├── css/              # Stylesheets
│   │   │   ├── js/               # JavaScript modules
│   │   │   └── images/           # Static images
│   │   ├── components/           # Reusable UI components
│   │   ├── pages/                # Application pages
│   │   ├── services/             # API communication
│   │   └── utils/                # Frontend utilities
│   ├── dist/                     # Built assets (production)
│   ├── public/                   # Static files
│   └── tests/                    # Frontend tests
│
├── docker/                        # Container orchestration
│   ├── docker-compose.yml        # Production
│   ├── docker-compose.dev.yml    # Development
│   └── init-scripts/
│
├── nginx/                         # API Gateway configuration
│   ├── nginx.conf                # Main configuration
│   └── conf.d/
│       ├── api.conf              # Backend routing
│       └── frontend.conf         # Frontend routing
│
└── docs/                          # Documentation
    ├── architecture/
    ├── api/
    └── deployment/
```

## Migration Strategy

### Phase 1: Backend API Isolation

**Objectives**:
- Extract pure API functionality from mixed application
- Remove static file serving from Ruby application
- Establish clear API contracts

**Tasks**:
1. Create dedicated `backend/` directory structure
2. Move Ruby codebase to `backend/app/`
3. Remove static file serving from config.ru
4. Update API endpoints to be JSON-only
5. Implement CORS for cross-origin frontend access
6. Create backend Dockerfile with multi-stage builds

**Expected Outcome**: Pure API service accessible at `http://localhost:4000/api`

### Phase 2: Frontend Service Extraction

**Objectives**:
- Extract frontend assets from Ruby codebase
- Establish independent frontend build process
- Implement modern frontend tooling

**Tasks**:
1. Create dedicated `frontend/` directory structure
2. Move HTML/CSS/JS files from `lib/blueprintsCLI/public/`
3. Setup modern build tooling (Vite, Webpack, or Parcel)
4. Implement module system for JavaScript
5. Add CSS preprocessing and optimization
6. Create frontend Dockerfile for static file serving
7. Update API calls to target backend service

**Expected Outcome**: Independent frontend service at `http://localhost:3000`

### Phase 3: Container Orchestration

**Objectives**:
- Implement Docker-based development and production environments
- Establish service communication patterns
- Add supporting services (database, cache)

**Tasks**:
1. Create production Docker Compose configuration
2. Create development Docker Compose configuration
3. Setup PostgreSQL with pgvector extension
4. Setup Redis for caching and background jobs
5. Configure Nginx as API gateway and reverse proxy
6. Implement health checks and service dependencies

**Expected Outcome**: Complete containerized application stack

### Phase 4: Advanced Features Integration

**Objectives**:
- Add monitoring, logging, and observability
- Implement background job processing
- Setup CI/CD pipeline

**Tasks**:
1. Add Sidekiq for background job processing
2. Implement structured logging across services
3. Add Prometheus metrics and Grafana dashboards
4. Setup automated testing for both services
5. Create deployment scripts and CI/CD workflows

**Expected Outcome**: Production-ready application with full observability

## Service Communication Patterns

### API Gateway Pattern

**Implementation**: Nginx reverse proxy routing requests to appropriate services

```
Client Request → Nginx Gateway → {Frontend Service, Backend API}
```

**Routing Rules**:
- `/api/*` → Backend API service
- `/*` → Frontend static files
- `/health` → Service health checks

**Benefits**:
- Single entry point for external traffic
- SSL termination at gateway level
- Load balancing and failover capabilities
- Request/response modification capabilities

### Inter-Service Communication

**Backend ↔ Database**: Direct connection via Sequel ORM
**Backend ↔ Redis**: Direct connection for caching and job queues
**Frontend ↔ Backend**: HTTP REST API calls via API gateway
**Background Jobs**: Redis-based job queues with Sidekiq workers

## Development Workflow

### Local Development Setup

```bash
# Start development environment
docker-compose -f docker/docker-compose.dev.yml up

# Access services:
# Frontend: http://localhost:3000 (with hot reloading)
# Backend API: http://localhost:4000/api (with live reload)
# Database: localhost:5433 (postgres/dev_password)
# Redis: localhost:6380
```

**Development Features**:
- Hot reloading for both frontend and backend
- Volume mounts for live code editing
- Debug ports exposed for IDE integration
- Separate development database with sample data
- Development mail catcher for email testing

### Testing Strategy

**Backend Testing**:
- Unit tests for models and services
- Integration tests for API endpoints
- Database transaction rollback for test isolation

**Frontend Testing**:
- Component unit tests with Jest/Vitest
- Integration tests for API communication
- End-to-end tests with Playwright/Cypress

**System Testing**:
- Docker Compose test environment
- API contract testing between services
- Performance testing under load

### Production Deployment

**Build Process**:
1. Frontend: Bundle and optimize assets
2. Backend: Create production Ruby image
3. Database: Run migrations and seed data
4. Services: Deploy with health checks

**Deployment Strategy**:
- Blue-green deployment for zero-downtime updates
- Database migration safety checks
- Automated rollback on health check failures
- Monitoring and alerting integration

## Benefits of Service Separation

### Development Benefits

1. **Independent Development**: Frontend and backend teams can work independently
2. **Technology Freedom**: Each service can use optimal technology stack
3. **Faster Iteration**: Changes don't require full application restart
4. **Focused Testing**: Service-specific test suites with faster feedback
5. **Better Debugging**: Isolated service logs and metrics

### Operational Benefits

1. **Independent Scaling**: Scale frontend and backend based on actual demand
2. **Fault Isolation**: Failure in one service doesn't crash entire application
3. **Deployment Flexibility**: Deploy services independently with different schedules
4. **Resource Optimization**: Optimize container resources per service requirements
5. **Monitoring Granularity**: Service-specific metrics and alerting

### Maintenance Benefits

1. **Clear Boundaries**: Well-defined service responsibilities
2. **Code Organization**: Related code grouped within service boundaries
3. **Dependency Management**: Service-specific dependencies without conflicts
4. **Security Isolation**: Reduced attack surface per service
5. **Team Ownership**: Clear ownership model for different services

## Migration Timeline

**Week 1-2**: Backend API isolation and containerization
**Week 3-4**: Frontend service extraction and tooling setup
**Week 5-6**: Container orchestration and service integration
**Week 7-8**: Testing, optimization, and production deployment

This separation strategy transforms the blueprintsCLI from a monolithic application with mixed concerns into a modern, scalable, and maintainable microservices architecture that supports independent development, deployment, and scaling of each service component.