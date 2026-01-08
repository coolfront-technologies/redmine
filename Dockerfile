#FROM ruby:2.0
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

# Add PostgreSQL 12 repository and install modern libpq
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt-get update && \
    apt-get install -y postgresql-client-12 libpq-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy everything FIRST
COPY . .

# Copy main Gemfile and Gemfile.lock
#COPY Gemfile ./

# Copy plugin Gemfile and Gemfile.lock
#COPY plugins/redmine_s3/Gemfile plugins/redmine_s3/Gemfile

# Install Bundler
RUN gem install bundler -v 1.17.3

# Configure bundler to skip MySQL-related gems
ENV BUNDLE_WITHOUT="development:test:rmagick"
ENV BUNDLE_FORCE_RUBY_PLATFORM="true"

# Remove MySQL gems from Gemfile
RUN sed -i '/gem.*mysql2/d' Gemfile && \
    sed -i '/activerecord-jdbcmysql-adapter/d' Gemfile && \
    sed -i '/gem.*ffi/d' Gemfile && \
    rm -f Gemfile.lock && \
    find . -name "Gemfile.lock" -delete

# Install main app gems (exclude MySQL gems)
# This will also install plugin gems because main Gemfile uses eval_gemfile
RUN bundle install

# Install plugin gems explicitly to ensure they're available
WORKDIR /app/plugins/redmine_s3
RUN bundle install --without development test rmagick

# Go back to app directory
WORKDIR /app

# Patch the redmine_s3 plugin to require aws-sdk with v1 compatibility
RUN echo "=== Patching redmine_s3 plugin to require aws-sdk ===" && \
    if [ -f plugins/redmine_s3/lib/redmine_s3/connection.rb ]; then \
      sed -i "1irequire 'aws-sdk'\nAWS = Aws unless defined?(AWS)" plugins/redmine_s3/lib/redmine_s3/connection.rb && \
      echo "Patched connection.rb with AWS SDK v2 compatibility" && \
      head -10 plugins/redmine_s3/lib/redmine_s3/connection.rb; \
    else \
      echo "connection.rb not found - checking alternate locations"; \
      find plugins -name "connection.rb" -type f; \
    fi

# Patch the PostgreSQL adapter AFTER all bundle installs are complete
# This ensures the gem won't be reinstalled and the patch won't be lost
RUN echo "=== Finding ActiveRecord gem location ===" && \
    ADAPTER_FILE=$(find /usr/local/bundle/gems -name "postgresql_adapter.rb" -path "*/activerecord-*/lib/active_record/connection_adapters/*" | head -1) && \
    echo "Found adapter at: $ADAPTER_FILE" && \
    if [ -z "$ADAPTER_FILE" ]; then echo "ERROR: postgresql_adapter.rb not found!"; exit 1; fi && \
    echo "=== Checking for 'panic' before patching ===" && \
    grep -n "client_min_messages.*panic" "$ADAPTER_FILE" || echo "Warning: 'panic' not found in expected format" && \
    echo "=== Applying patch ===" && \
    sed -i "s/'panic'/'error'/g" "$ADAPTER_FILE" && \
    echo "=== Verifying patch was applied ===" && \
    grep -n "client_min_messages" "$ADAPTER_FILE" | grep -E "(error|panic)" && \
    if grep -q "'panic'" "$ADAPTER_FILE"; then echo "ERROR: Patch failed - 'panic' still present!"; exit 1; fi && \
    echo "=== Patch verification complete - SUCCESS ==="

EXPOSE 3010
CMD ["sh", "-c", "echo 'Starting Rails application...' && echo 'PORT='${PORT:-3010} && echo 'DATABASE_URL='$DATABASE_URL && echo '=== RUNTIME: Checking if patch was applied ===' && ADAPTER_FILE=$(find /usr/local/bundle/gems -name 'postgresql_adapter.rb' -path '*/activerecord-*/lib/active_record/connection_adapters/*' | head -1) && echo \"Adapter file: $ADAPTER_FILE\" && grep -n \"client_min_messages.*'error'\" \"$ADAPTER_FILE\" && echo '=== Patch IS present ===' || echo '=== WARNING: Patch NOT present! ===' && echo '=== Checking if AWS SDK gem is installed ===' && bundle show aws-sdk && echo '=== AWS SDK is installed ===' || echo '=== WARNING: AWS SDK NOT installed! ===' && echo 'Checking preinitializer...' && cat config/preinitializer.rb && echo 'Running bundle exec...' && bundle exec rails server -b 0.0.0.0 -p ${PORT:-3010} 2>&1 || (echo 'Rails server failed with exit code:' $? && tail -100 log/production.log 2>/dev/null && sleep 30)"]
