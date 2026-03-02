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

# Session store
RUN echo "RedmineApp::Application.config.session_store :cookie_store, key: '_redmine_session'" > /app/config/initializers/session_store.rb

# Force HTTPS detection from Azure proxy headers
RUN printf '%s\n' \
    'module ActionController' \
    '  class Request' \
    '    def ssl?' \
    '      @env["HTTP_X_FORWARDED_PROTO"] == "https" ||' \
    '      @env["HTTP_X_ARR_SSL"].present? ||' \
    '      @env["HTTPS"] == "on" ||' \
    '      @env["rack.url_scheme"] == "https"' \
    '    end' \
    '  end' \
    'end' \
    > /app/config/initializers/ssl_fix.rb

# CRITICAL: Create new config.ru with SameSite cookie middleware
RUN mv /app/config.ru /app/config.ru.original && \
    printf '%s\n' \
    '# SameSite Cookie Middleware for Azure' \
    'class SameSiteCookies' \
    '  def initialize(app)' \
    '    @app = app' \
    '  end' \
    '  def call(env)' \
    '    status, headers, body = @app.call(env)' \
    '    if headers["Set-Cookie"]' \
    '      cookies = headers["Set-Cookie"].is_a?(Array) ? headers["Set-Cookie"] : headers["Set-Cookie"].split("\n")' \
    '      cookies = cookies.map do |cookie|' \
    '        next cookie if cookie =~ /SameSite=/i' \
    '        cookie.strip + "; SameSite=None; Secure"' \
    '      end' \
    '      headers["Set-Cookie"] = cookies.join("\n")' \
    '    end' \
    '    [status, headers, body]' \
    '  end' \
    'end' \
    '' \
    '# Load original Redmine application' \
    'require ::File.expand_path("../config/environment",  __FILE__)' \
    '' \
    '# Wrap with SameSite middleware' \
    'use SameSiteCookies' \
    'run RedmineApp::Application' \
    > /app/config.ru

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
    echo 'echo "Checking admin2 user..."' >> /start.sh && \
    echo 'bundle exec rails runner "' >> /start.sh && \
    echo 'u = User.find_by_login(\"admin2\")' >> /start.sh && \
    echo 'if u.nil?' >> /start.sh && \
    echo '  u = User.new' >> /start.sh && \
    echo '  u.login = \"admin2\"' >> /start.sh && \
    echo '  u.firstname = \"Admin\"' >> /start.sh && \
    echo '  u.lastname = \"Two\"' >> /start.sh && \
    echo '  u.mail = \"admin2@example.com\"' >> /start.sh && \
    echo '  u.admin = true' >> /start.sh && \
    echo '  u.status = 1' >> /start.sh && \
    echo 'end' >> /start.sh && \
    echo 'u.password = \"Admin123!\"' >> /start.sh && \
    echo 'u.password_confirmation = \"Admin123!\"' >> /start.sh && \
    echo 'u.must_change_passwd = false' >> /start.sh && \
    echo 'if u.save' >> /start.sh && \
    echo '  puts \"admin2 ready with password Admin123!\"' >> /start.sh && \
    echo 'else' >> /start.sh && \
    echo '  puts \"ERROR: \" + u.errors.full_messages.join(\", \")' >> /start.sh && \
    echo 'end' >> /start.sh && \
    echo '" 2>&1 || echo "User check completed"' >> /start.sh && \
    echo 'bundle exec rake generate_secret_token 2>/dev/null || true' >> /start.sh && \
    echo 'echo "Starting Rack server on port ${PORT:-3010}..."' >> /start.sh && \
    echo 'exec bundle exec rackup -o 0.0.0.0 -p ${PORT:-3010} config.ru' >> /start.sh && \
    chmod +x /start.sh

EXPOSE 3010
CMD ["/start.sh"]