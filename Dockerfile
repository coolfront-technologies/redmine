FROM ruby:2.3

# Fix for archived Debian Stretch repos
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99ignore-validation && \
    echo 'Acquire::AllowInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99ignore-validation && \
    echo 'Acquire::AllowDowngradeToInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99ignore-validation

# Install base packages first
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
      wget

# Download and install newer libpq manually (version 12 supports SCRAM)
RUN wget --no-check-certificate https://ftp.postgresql.org/pub/source/v12.18/postgresql-12.18.tar.gz && \
    tar -xzf postgresql-12.18.tar.gz && \
    cd postgresql-12.18 && \
    ./configure --without-readline --without-zlib && \
    make -C src/interfaces/libpq && \
    make -C src/interfaces/libpq install && \
    make -C src/bin/pg_config install && \
    make -C src/include install && \
    cd .. && rm -rf postgresql-12.18 postgresql-12.18.tar.gz && \
    ldconfig

# Set environment variables so pg gem finds the new libpq at BUILD and RUNTIME
ENV PATH="/usr/local/pgsql/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/pgsql/lib"
ENV LIBRARY_PATH="/usr/local/pgsql/lib"
ENV C_INCLUDE_PATH="/usr/local/pgsql/include"

# Also add to ldconfig permanently
RUN echo "/usr/local/pgsql/lib" > /etc/ld.so.conf.d/postgresql.conf && ldconfig

# Debug: verify libpq version
RUN /usr/local/pgsql/bin/pg_config --version && \
    ls -la /usr/local/pgsql/lib/

WORKDIR /app

# Copy Gemfiles first (better layer caching)
COPY Gemfile Gemfile.lock ./
COPY plugins/redmine_s3/Gemfile plugins/redmine_s3/Gemfile
COPY plugins/redmine_s3/Gemfile.lock plugins/redmine_s3/Gemfile.lock

# Install Bundler compatible with Ruby 2.3
RUN gem install bundler -v 1.17.3

# Disable SSL verification (Ruby 2.3 + modern SSL workaround)
RUN bundle config set --local ssl_verify_mode 0

# Configure bundler to use the new pg_config for building pg gem
RUN bundle config build.pg --with-pg-config=/usr/local/pgsql/bin/pg_config

# Install main app gems (pg will be built with new libpq)
RUN bundle install --without development test rmagick

# Verify pg gem is linked to correct libpq
RUN ldd $(find /usr/local/bundle -name "pg_ext.so" | head -1) | grep libpq

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
    echo 'exec bundle exec rails server -b 0.0.0.0 -p ${PORT:-3010}' >> /start.sh && \
    chmod +x /start.sh
# Copy the rest of the application
COPY . .
EXPOSE 3010
CMD ["/start.sh"]