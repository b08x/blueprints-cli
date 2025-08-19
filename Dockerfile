FROM ruby:3.3-alpine

# Install build dependencies
RUN apk add --no-cache \
  build-base \
  postgresql-dev \
  git \
  curl

# Set working directory
WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock blueprintsCLI.gemspec ./
RUN bundle config set --local deployment 'true' && \
  bundle config set --local without 'development test' && \
  bundle install

# Copy application code
COPY . .

# Create directories for logs and tmp
RUN mkdir -p log tmp

# Expose port 3000
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/api/health || exit 1

# Start the web application using the existing web_config.ru
CMD ["bundle", "exec", "rackup", "lib/blueprintsCLI/web_config.ru", "-o", "0.0.0.0", "-p", "3000"]