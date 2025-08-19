# BlueprintsCLI Frontend Service

## Overview

The BlueprintsCLI frontend is a modern Single Page Application (SPA) that provides a web interface for managing and interacting with code blueprints. It's designed as a containerized service that integrates seamlessly with the Ruby backend API.

## Architecture

### Technology Stack
- **Base**: Vanilla JavaScript with modern ES6+ features
- **Styling**: Tailwind CSS (via CDN) with custom CSS variables
- **Fonts**: Space Grotesk from Google Fonts
- **Server**: Nginx for static serving and API proxying
- **Container**: Alpine Linux for minimal attack surface

### Service Design
- **Production**: Multi-stage Docker build with security optimizations
- **Development**: Hot-reload capable with live volume mounts
- **API Integration**: Intelligent API URL detection and CORS handling
- **Security**: Comprehensive security headers and CSP policies

## Features

### Core Functionality
1. **Blueprint Search**: Search through existing code templates and patterns
2. **Code Generation**: Generate new code using AI-powered assistance
3. **Blueprint Submission**: Submit and catalog new blueprints
4. **Blueprint Viewing**: Browse, examine, and understand blueprint details

### User Experience
- **Responsive Design**: Mobile-first responsive layout
- **Dark Theme**: Modern dark theme with purple/orange accents
- **Real-time Search**: Instant search with API integration
- **Loading States**: Proper loading and error state management
- **Navigation**: Intuitive sidebar navigation between features

## Development

### Local Development Setup

1. **Start Development Services**:
   ```bash
   cd docker
   docker compose -f docker-compose.dev.yml up frontend-dev backend-dev
   ```

2. **Access Development Frontend**:
   - Frontend: http://localhost:8080
   - Backend API: http://localhost:3000/api

### Hot Reloading
The development configuration supports hot reloading:
- HTML/CSS/JS changes reflect immediately
- No build step required for development
- Volume mounts for live editing

### Development Features
- Relaxed CORS policies for local development
- Debug-friendly error messages
- No asset caching for immediate updates
- Development-specific nginx configuration

## Production Deployment

### Build Process
The production build uses a multi-stage Docker approach:

1. **Build Stage**: 
   - Prepares and optimizes static assets
   - Sets proper file permissions
   - Future: Asset compilation and optimization

2. **Production Stage**:
   - Minimal nginx:alpine base image
   - Non-root user execution
   - Optimized nginx configuration
   - Security headers and rate limiting

### Production Features
- **Performance**: Gzip compression, asset caching, CDN-friendly headers
- **Security**: CSP policies, security headers, rate limiting
- **Monitoring**: Health checks, structured logging
- **Scaling**: Resource limits, efficient container sizing

## Configuration

### Environment Variables
Frontend configuration is managed through environment variables:

```bash
# Copy and customize
cp docker/.env.frontend.example docker/.env.frontend
```

Key configurations:
- `FRONTEND_PORT`: Production service port (default: 8080)
- `FRONTEND_DEV_PORT`: Development service port (default: 8080)
- `API_BASE_URL`: Backend API endpoint for frontend JavaScript

### Nginx Configuration Files

1. **nginx.production.conf**: Production-optimized configuration
   - API reverse proxy with upstream backend
   - Rate limiting and security headers
   - Asset caching and compression
   - CORS handling for API requests

2. **nginx.development.conf**: Development-friendly configuration
   - Relaxed security policies
   - No caching for immediate updates
   - Enhanced debugging and logging

3. **nginx.security.conf**: Comprehensive security headers
   - Content Security Policy (CSP)
   - XSS protection and frame options
   - Permissions policy and feature restrictions

## File Structure

```
frontend/
├── Dockerfile.production       # Production multi-stage build
├── Dockerfile.dev             # Development container
├── nginx.production.conf      # Production nginx config
├── nginx.development.conf     # Development nginx config
├── nginx.security.conf        # Security headers
├── pages/                     # HTML pages and page-specific assets
│   ├── index.html            # Main dashboard/search page
│   ├── generator.html        # Code generation interface
│   ├── submission.html       # Blueprint submission form
│   ├── viewer.html          # Blueprint viewing interface
│   ├── css/
│   │   └── app.css          # Custom styling and CSS variables
│   └── js/
│       ├── app.js           # Core application class and API client
│       ├── index.js         # Dashboard/search functionality
│       ├── generator.js     # Code generation logic
│       └── submission.js    # Blueprint submission logic
├── public/                    # Static public assets
│   ├── css/
│   └── js/
└── src/                      # Source files (future build system)
```

## API Integration

### API Client (`pages/js/app.js`)
The `BlueprintsApp` class provides:
- Environment-aware API URL detection
- Standardized request/response handling
- Error handling and loading states
- CORS-compatible request configuration

### API Endpoints
- `GET /api/blueprints` - List blueprints with optional search
- `GET /api/blueprints/:id` - Get specific blueprint
- `POST /api/blueprints` - Create new blueprint
- `POST /api/blueprints/generate` - Generate code from prompt
- `POST /api/blueprints/metadata` - Extract metadata from code

### Environment Detection
The frontend automatically detects its environment:
- **Development**: `localhost:8080` → API at `localhost:3000`
- **Production**: Docker environment → API at `backend-api:3000`
- **Fallback**: Relative paths for standalone deployment

## Security

### Content Security Policy
The production configuration includes a strict CSP that:
- Allows Tailwind CSS CDN and Google Fonts
- Restricts script execution to trusted sources
- Prevents XSS and injection attacks
- Controls resource loading and connections

### Rate Limiting
Nginx implements rate limiting for:
- API requests: 10 req/sec with burst capacity
- Static assets: 50 req/sec with burst capacity
- Protection against DoS and abuse

### Container Security
- Non-root user execution (`nginx-app:1001`)
- Minimal Alpine Linux base image
- Regular security updates
- Proper file permissions and ownership

## Monitoring & Health Checks

### Health Endpoints
- `/health` - Frontend service health check
- Returns `200 OK` with "healthy" text
- Used by Docker health checks and load balancers

### Logging
- Production: JSON structured logs with rotation
- Development: Debug-level logs for troubleshooting
- Access logs for monitoring and analytics
- Error logs for issue diagnosis

### Metrics
The frontend service provides metrics through:
- Docker container resource usage
- Nginx access and error logs
- Health check status and response times

## Troubleshooting

### Common Issues

1. **API Connection Failures**:
   - Check backend service health: `docker logs blueprintscli_backend_dev`
   - Verify network connectivity between containers
   - Review API URL configuration in browser dev tools

2. **Asset Loading Problems**:
   - Check nginx logs: `docker logs blueprintscli_frontend_dev`
   - Verify volume mounts in development
   - Ensure proper file permissions

3. **CORS Errors**:
   - Development: Check nginx.development.conf CORS headers
   - Production: Verify backend CORS configuration
   - Browser dev tools network tab for request details

### Debug Commands
```bash
# View frontend logs
docker logs blueprintscli_frontend_dev -f

# Access frontend container
docker exec -it blueprintscli_frontend_dev /bin/sh

# Test frontend health
curl http://localhost:8080/health

# Test API proxy
curl http://localhost:8080/api/blueprints
```

## Future Enhancements

### Planned Improvements
1. **Build System**: Webpack/Vite integration for asset optimization
2. **Testing**: E2E tests with Playwright or Cypress
3. **PWA Features**: Service workers and offline capability
4. **Performance**: Lazy loading and code splitting
5. **Accessibility**: WCAG compliance and screen reader support

### Customization Options
- Theme customization via CSS variables
- Feature toggles through environment variables
- API endpoint configuration
- Custom nginx configurations for specific needs