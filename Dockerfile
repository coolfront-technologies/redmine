FROM ruby:2.3

# Fix for archived Debian Stretch repos
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99ignore-validation && \
    echo 'Acquire::AllowInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99ignore-validation && \
    echo 'Acquire::AllowDowngradeToInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99ignore-validation

# Install base packages
RUN apt-get update && apt-get install -y --allow-unauthenticated \
      curl \
      gnupg2 \
      ca-certificates \
      build-essential \
      libxml2-dev \
      libxslt1-dev \
      libmagickwand-dev \
      libmagickcore-dev \
      git \
      wget \
      imagemagick \
      libssl-dev

# Remove old libpq completely to avoid conflicts
RUN apt-get remove -y libpq5 libpq-dev || true

# Download and install newer libpq manually (version 12 supports SCRAM)
RUN wget --no-check-certificate https://ftp.postgresql.org/pub/source/v12.18/postgresql-12.18.tar.gz && \
    tar -xzf postgresql-12.18.tar.gz && \
    cd postgresql-12.18 && \
    ./configure --without-readline --with-openssl && \
    make -C src/interfaces/libpq && \
    make -C src/interfaces/libpq install && \
    make -C src/bin/pg_config install && \
    make -C src/include install && \
    cd .. && rm -rf postgresql-12.18 postgresql-12.18.tar.gz

# Add libpq to system library path permanently
RUN echo "/usr/local/pgsql/lib" > /etc/ld.so.conf.d/postgresql.conf && ldconfig

# Verify libpq is properly installed
RUN ls -la /usr/local/pgsql/lib/ && \
    /usr/local/pgsql/bin/pg_config --version && \
    /usr/local/pgsql/bin/pg_config --libdir

# Set environment variables BEFORE gem installation
ENV PATH="/usr/local/pgsql/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/pgsql/lib"
ENV LIBRARY_PATH="/usr/local/pgsql/lib"
ENV CPATH="/usr/local/pgsql/include"
ENV RAILS_ENV=production

WORKDIR /app

# Copy Gemfiles first (better layer caching)
COPY Gemfile Gemfile.lock ./

# Create plugins directory structure and copy plugin Gemfiles
RUN mkdir -p plugins/redmine_s3
COPY plugins/redmine_s3/Gemfile plugins/redmine_s3/Gemfile
COPY plugins/redmine_s3/Gemfile.lock plugins/redmine_s3/Gemfile.lock

# Install Bundler compatible with Ruby 2.3
RUN gem install bundler -v 1.17.3

# Configure bundler to use the new pg_config for building pg gem
RUN bundle config build.pg --with-pg-config=/usr/local/pgsql/bin/pg_config && \
    bundle config --local build.pg --with-pg-config=/usr/local/pgsql/bin/pg_config

# Install main app gems (pg will be built with new libpq)
RUN bundle install --without development test rmagick

# CRITICAL: Verify pg gem is linked to correct libpq (should show /usr/local/pgsql/lib/libpq.so.5)
RUN echo "=== Verifying pg gem linkage ===" && \
    PG_EXT=$(find /usr/local/bundle -name "pg_ext.so" | head -1) && \
    echo "Found pg_ext.so at: $PG_EXT" && \
    ldd "$PG_EXT" && \
    ldd "$PG_EXT" | grep -q "/usr/local/pgsql/lib/libpq" && \
    echo "SUCCESS: pg gem is linked to new libpq" || \
    (echo "ERROR: pg gem is NOT linked to new libpq - rebuilding..." && \
     gem uninstall pg -a -x --force && \
     gem install pg -v '0.18.4' -- --with-pg-config=/usr/local/pgsql/bin/pg_config && \
     ldd $(find /usr/local/bundle -name "pg_ext.so" | head -1))

# Install plugin gems
WORKDIR /app/plugins/redmine_s3
RUN bundle install --without development test rmagick

WORKDIR /app

# Copy the rest of the application
COPY . .

# Create necessary directories
RUN mkdir -p tmp/pids tmp/sockets log public/plugin_assets files

# Patch redmine_s3 plugin for aws-sdk-v1
RUN if [ -f plugins/redmine_s3/lib/redmine_s3/connection.rb ]; then \
      sed -i "s/require 'aws-sdk'/require 'aws-sdk-v1'/" plugins/redmine_s3/lib/redmine_s3/connection.rb; \
    fi

# Patch PostgreSQL adapter to fix client_min_messages
RUN ADAPTER_FILE=$(find /usr/local/bundle/gems -name "postgresql_adapter.rb" -path "*/activerecord-*/lib/active_record/connection_adapters/*" | head -1) && \
    if [ -n "$ADAPTER_FILE" ]; then \
      sed -i "s/'panic'/'error'/g" "$ADAPTER_FILE"; \
    fi

# Create startup script
COPY <<'STARTEOF' /start.sh
#!/bin/bash
set -e

echo "=== Starting Redmine Application ==="

# CRITICAL: Ensure libpq is found at runtime
export LD_LIBRARY_PATH="/usr/local/pgsql/lib:$LD_LIBRARY_PATH"
export PATH="/usr/local/pgsql/bin:$PATH"
export RAILS_ENV=production

# Debug: Verify libpq linkage at runtime
echo "Verifying libpq linkage..."
PG_EXT=$(find /usr/local/bundle -name "pg_ext.so" | head -1)
if [ -n "$PG_EXT" ]; then
    echo "pg_ext.so location: $PG_EXT"
    ldd "$PG_EXT" | grep libpq
else
    echo "WARNING: pg_ext.so not found"
fi

# Set SECRET_TOKEN from SECRET_KEY_BASE if not set
export SECRET_TOKEN=${SECRET_TOKEN:-${SECRET_KEY_BASE}}

# Ensure SECRET_TOKEN is set
if [ -z "$SECRET_TOKEN" ]; then
  echo "Warning: SECRET_TOKEN not set, generating temporary one..."
  export SECRET_TOKEN=$(ruby -rsecurerandom -e 'puts SecureRandom.hex(64)')
fi

# Create database.yml from DATABASE_URL
cat > config/database.yml <<DBEOF
production:
  adapter: postgresql
  encoding: unicode
  url: <%= ENV["DATABASE_URL"] %>
  pool: 5
  timeout: 5000
DBEOF

echo "Database configuration created"

# Create S3 configuration if S3 settings are provided
if [ -n "$S3_BUCKET" ]; then
  cat > config/s3.yml <<S3EOF
production:
  access_key_id: ${S3_ACCESS_KEY_ID}
  secret_access_key: ${S3_SECRET_ACCESS_KEY}
  bucket: ${S3_BUCKET}
  endpoint: ${S3_ENDPOINT:-}
  secure: ${S3_SECURE:-true}
S3EOF
  echo "S3 configuration created"
fi

# Ensure directories exist
mkdir -p tmp/pids tmp/sockets log public/plugin_assets files

# Wait for database to be ready
echo "Waiting for database connection..."
MAX_RETRIES=30
RETRY_COUNT=0
until bundle exec rails runner "ActiveRecord::Base.connection.execute('SELECT 1')" 2>/dev/null; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "ERROR: Could not connect to database after $MAX_RETRIES attempts"
    echo "Attempting to show connection error..."
    bundle exec rails runner "ActiveRecord::Base.connection" 2>&1 || true
    exit 1
  fi
  echo "Waiting for database... attempt $RETRY_COUNT/$MAX_RETRIES"
  sleep 2
done
echo "Database connection established!"

# Run database migrations
echo "Running database migrations..."
bundle exec rake db:migrate RAILS_ENV=production 2>&1 || echo "Migration completed (or no migrations needed)"

# Generate session store secret if needed
bundle exec rake generate_secret_token 2>/dev/null || echo "Secret token exists"

echo "Starting Rails server on port ${PORT:-3010}..."
exec bundle exec rails server -b 0.0.0.0 -p ${PORT:-3010}
STARTEOF

RUN chmod +x /start.sh

# Final verification
RUN echo "=== Final Build Verification ===" && \
    ldconfig -p | grep libpq && \
    /usr/local/pgsql/bin/pg_config --version

EXPOSE 3010
CMD ["/start.sh"]