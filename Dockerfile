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

# Replace aws-sdk 2.x with aws-sdk-v1 for compatibility with old Redmine plugin
RUN sed -i "s/gem 'aws-sdk', '~> 2.11'/gem 'aws-sdk-v1'/g" plugins/redmine_s3/Gemfile && \
    echo "=== Updated plugin Gemfile to use aws-sdk-v1 ===" && \
    grep aws-sdk plugins/redmine_s3/Gemfile

# Install main app gems (exclude MySQL gems)
# This will also install plugin gems because main Gemfile uses eval_gemfile
RUN bundle install

# Install plugin gems explicitly to ensure they're available
WORKDIR /app/plugins/redmine_s3
RUN bundle install --without development test rmagick

# Go back to app directory
WORKDIR /app

# Patch redmine_s3 plugin to use correct require for aws-sdk-v1
RUN echo "=== Patching redmine_s3 plugin to use aws-sdk-v1 require ===" && \
    if [ -f plugins/redmine_s3/lib/redmine_s3/connection.rb ]; then \
      sed -i "s/require 'aws-sdk'/require 'aws-sdk-v1'/" plugins/redmine_s3/lib/redmine_s3/connection.rb && \
      echo "Patched connection.rb" && \
      head -5 plugins/redmine_s3/lib/redmine_s3/connection.rb; \
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

# Patch the Setting model to fix YAML serialization issues
RUN echo "=== Patching Setting model for YAML compatibility ===" && \
    sed -i '171s/.*/      default_value = read_attribute(:value) rescue nil; return default_value if default_value.is_a?(Integer); b.accept(read_attribute(:value))/' app/models/setting.rb && \
    echo "Setting model patched" && \
    head -175 app/models/setting.rb | tail -10

# Create startup script to generate database.yml at runtime
RUN echo '#!/bin/sh' > /start.sh && \
    echo 'export SECRET_TOKEN=${SECRET_TOKEN:-${SECRET_KEY_BASE}}' >> /start.sh && \
    echo 'cat > config/database.yml <<DBEOF' >> /start.sh && \
    echo 'production:' >> /start.sh && \
    echo '  adapter: postgresql' >> /start.sh && \
    echo '  encoding: unicode' >> /start.sh && \
    echo '  url: <%= ENV["DATABASE_URL"] %>' >> /start.sh && \
    echo 'DBEOF' >> /start.sh && \
    echo 'echo "Running database migrations..."' >> /start.sh && \
    echo 'bundle exec rake db:migrate RAILS_ENV=production' >> /start.sh && \
    echo 'echo "Initializing Redmine..."' >> /start.sh && \
    echo 'RAILS_ENV=production bundle exec rails runner "Setting.create(name: \"rest_api_enabled\", value: \"1\") if Setting.where(name: \"rest_api_enabled\").empty?" 2>/dev/null || true' >> /start.sh && \
    echo 'echo "Starting Rails server..."' >> /start.sh && \
    echo 'bundle exec rails server -b 0.0.0.0 -p ${PORT:-3010}' >> /start.sh && \
    chmod +x /start.sh

EXPOSE 3010
CMD ["/start.sh"]
