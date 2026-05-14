FROM ruby:2.6.10

# Install build dependencies
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      imagemagick \
      libmagickwand-dev \
      git \
      curl \
      wget \
      gnupg \
      lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Add PostgreSQL 12 repository and install client
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt-get update && \
    apt-get install -y postgresql-client-12 libpq-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy application code
COPY . .

# Install Bundler
RUN gem install bundler -v 1.17.3

# Configure bundler
ENV BUNDLE_WITHOUT="development:test:rmagick"
ENV BUNDLE_FORCE_RUBY_PLATFORM="true"

# Remove MySQL gems from Gemfile
RUN sed -i '/gem.*mysql2/d' Gemfile && \
    sed -i '/activerecord-jdbcmysql-adapter/d' Gemfile && \
    sed -i '/gem.*ffi/d' Gemfile && \
    rm -f Gemfile.lock && \
    find . -name "Gemfile.lock" -delete

# Update aws-sdk for redmine_s3 plugin compatibility
RUN sed -i "s/gem 'aws-sdk', '~> 2.11'/gem 'aws-sdk-v1'/g" plugins/redmine_s3/Gemfile

# Install gems
RUN bundle install

# Install plugin gems
WORKDIR /app/plugins/redmine_s3
RUN bundle install --without development test rmagick
WORKDIR /app

# Patch redmine_s3 plugin for aws-sdk-v1
RUN if [ -f plugins/redmine_s3/lib/redmine_s3/connection.rb ]; then \
      sed -i "s/require 'aws-sdk'/require 'aws-sdk-v1'/" plugins/redmine_s3/lib/redmine_s3/connection.rb; \
    fi

# Patch PostgreSQL adapter to fix client_min_messages
RUN ADAPTER_FILE=$(find /usr/local/bundle/gems -name "postgresql_adapter.rb" -path "*/activerecord-*/lib/active_record/connection_adapters/*" | head -1) && \
    sed -i "s/'panic'/'error'/g" "$ADAPTER_FILE"

# Create startup script
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'set -e' >> /start.sh && \
    echo 'export SECRET_TOKEN=${SECRET_TOKEN:-${SECRET_KEY_BASE}}' >> /start.sh && \
    echo 'export RAILS_ENV=production' >> /start.sh && \
    echo 'export RAILS_SERVE_STATIC_FILES=true' >> /start.sh && \
    echo 'echo "=== Redmine Container Startup ==="' >> /start.sh && \
    echo 'cat > config/database.yml <<DBEOF' >> /start.sh && \
    echo 'production:' >> /start.sh && \
    echo '  adapter: postgresql' >> /start.sh && \
    echo '  encoding: unicode' >> /start.sh && \
    echo '  url: <%= ENV["DATABASE_URL"] %>' >> /start.sh && \
    echo 'DBEOF' >> /start.sh && \
    echo 'mkdir -p tmp/pids tmp/sockets log files public/plugin_assets' >> /start.sh && \
    echo 'echo "Running database migrations..."' >> /start.sh && \
    echo 'bundle exec rake db:migrate RAILS_ENV=production 2>&1 || echo "Migrations done"' >> /start.sh && \
    echo 'bundle exec rake generate_secret_token 2>/dev/null || true' >> /start.sh && \
    echo 'echo "Starting Rack server on port ${PORT:-3010}..."' >> /start.sh && \
    echo 'exec bundle exec rackup -o 0.0.0.0 -p ${PORT:-3010} config.ru' >> /start.sh && \
    chmod +x /start.sh

EXPOSE 3010
CMD ["/start.sh"]