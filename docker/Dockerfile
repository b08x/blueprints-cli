FROM ruby:3.3-alpine

# Install build dependencies
RUN apk add --no-cache \
  build-base \
  postgresql-dev \
  libffi-dev \
  yaml-dev \
  git \
  curl

# Create non-root user for security
RUN addgroup -g 1000 -S app && \
  adduser -u 1000 -S app -G app

# Set working directory
WORKDIR /app

# Copy Gemfile, gemspec and install gems
COPY Gemfile Gemfile.lock blueprintsCLI.gemspec ./
COPY lib/blueprintsCLI/version.rb ./lib/blueprintsCLI/

RUN bundle config set --local without 'development test' && \ 
  bundle install --jobs 4 --retry 3

# Copy application code
COPY . .

# Create directories for logs and tmp, and change ownership to app user
RUN mkdir -p log tmp && \
  chown -R app:app /app

# Switch to non-root user
USER app

# Expose port 3000
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/api/health || exit 1

# Start the web application using the existing web_config.ru
CMD ["bundle", "exec", "rackup", "lib/blueprintsCLI/web_config.ru", "-o", "0.0.0.0", "-p", "3000"]