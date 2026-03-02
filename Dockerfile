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

# Fix session cookies - use database session store instead of cookies
RUN cat > /app/config/initializers/session_store.rb << 'SESSIONEOF'
# Use ActiveRecord session store to avoid cookie issues behind proxy
RedmineApp::Application.config.session_store :cookie_store, 
  key: '_redmine_session',
  expire_after: 1.day,
  secure: false,
  httponly: true
SESSIONEOF

# Patch ApplicationController to handle proxy headers
RUN cat > /app/config/initializers/proxy_fix.rb << 'PROXYEOF'
# Trust X-Forwarded headers from Azure App Service
class ActionController::Request
  def ssl?
    @env['HTTP_X_FORWARDED_PROTO'] == 'https' || @env['HTTPS'] == 'on' || super
  end
end if defined?(ActionController::Request)

# For newer Rails
module ActionDispatch
  class Request
    alias_method :original_ssl?, :ssl?
    def ssl?
      return true if headers['HTTP_X_FORWARDED_PROTO'] == 'https'
      return true if headers['X-Forwarded-Proto'] == 'https'
      original_ssl?
    end
  end
end if defined?(ActionDispatch::Request)
PROXYEOF

# Create startup script
RUN cat > /start.sh << 'STARTEOF'
#!/bin/bash
set -e

export SECRET_TOKEN=${SECRET_TOKEN:-${SECRET_KEY_BASE}}
export RAILS_ENV=production

echo "=== Redmine Container Startup ==="

# Create database.yml
cat > config/database.yml <<DBEOF
production:
  adapter: postgresql
  encoding: unicode
  url: <%= ENV["DATABASE_URL"] %>
DBEOF

mkdir -p tmp/pids tmp/sockets log files public/plugin_assets

echo "Running database migrations..."
bundle exec rake db:migrate RAILS_ENV=production 2>&1 || echo "Migrations done"

# Create admin2 user if not exists
echo "Checking admin2 user..."
bundle exec rails runner "
  unless User.find_by(login: 'admin2')
    u = User.new
    u.login = 'admin2'
    u.firstname = 'Admin'
    u.lastname = 'Two'
    u.mail = 'admin2@example.com'
    u.admin = true
    u.status = 1
    u.password = 'Admin123!'
    u.password_confirmation = 'Admin123!'
    u.must_change_passwd = false
    if u.save
      puts 'SUCCESS: admin2 created with password Admin123!'
    else
      puts 'ERROR: ' + u.errors.full_messages.join(', ')
    end
  else
    puts 'admin2 user already exists'
    # Reset password just in case
    u = User.find_by(login: 'admin2')
    u.password = 'Admin123!'
    u.password_confirmation = 'Admin123!'
    u.must_change_passwd = false
    u.save
    puts 'admin2 password reset to Admin123!'
  end
" 2>&1 || echo "User creation check completed"

# Generate secret token
bundle exec rake generate_secret_token 2>/dev/null || true

echo "Starting Rails server on port ${PORT:-3010}..."
exec bundle exec rails server -b 0.0.0.0 -p ${PORT:-3010}
STARTEOF

RUN chmod +x /start.sh

EXPOSE 3010
CMD ["/start.sh"]