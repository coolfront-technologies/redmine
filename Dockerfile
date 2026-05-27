FROM ruby:2.7.6

# Install build dependencies
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      imagemagick \
      libmagickwand-dev \
      default-libmysqlclient-dev \
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
RUN gem install bundler -v 2.1.4

# Configure bundler
ENV BUNDLE_WITHOUT="development:test:minimagick"
ENV BUNDLE_FORCE_RUBY_PLATFORM="true"

# Install gems
RUN bundle install

RUN if [ -f plugins/amazon_s3/Gemfile ]; then \
      cd plugins/amazon_s3 && bundle install; \
    fi

# Patch PostgreSQL adapter to fix client_min_messages
RUN ADAPTER_FILE=$(find /usr/local/bundle/gems -name "postgresql_adapter.rb" -path "*/activerecord-*/lib/active_record/connection_adapters/*" | head -1) && \
    sed -i "s/'panic'/'error'/g" "$ADAPTER_FILE"

# Create startup script
RUN cat <<'EOS' > /start.sh
#!/bin/bash
set -e
export SECRET_TOKEN="${SECRET_TOKEN:-${SECRET_KEY_BASE}}"
export RAILS_ENV=production
export RAILS_SERVE_STATIC_FILES=true

echo "=== Redmine Container Startup ==="
mkdir -p tmp/pids tmp/sockets log files public/plugin_assets

# .:/app mount replaces image code with host Gemfile.lock; sync gems if needed
if ! bundle check >/dev/null 2>&1; then
  echo "Installing gems from Gemfile.lock..."
  bundle install --jobs 4
fi

cat > config/database.yml <<'DBYAML'
production:
  adapter: postgresql
  encoding: unicode
  url: <%= ENV["DATABASE_URL"] %>
DBYAML

if [[ "${REDMINE_NO_DB_MIGRATE:-}" == "1" ]]; then
  echo "Skipping db:migrate (REDMINE_NO_DB_MIGRATE=1)"
elif [[ -n "${WEBSITE_SITE_NAME:-}" ]]; then
  echo "Skipping db:migrate (Azure App Service: WEBSITE_SITE_NAME is set — run migrations via release pipeline or rake task if needed)"
else
  echo "Running database migrations..."
  bundle exec rake db:migrate RAILS_ENV=production 2>&1 || echo "Migrations done"
fi

bundle exec rake generate_secret_token 2>/dev/null || true
echo "Starting Rack server on port ${PORT:-3010}..."
exec bundle exec rackup -o 0.0.0.0 -p "${PORT:-3010}" config.ru
EOS

RUN chmod +x /start.sh

EXPOSE 3010
CMD ["/start.sh"]