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
RUN bundle install

# Install plugin gems
WORKDIR /app/plugins/redmine_s3
RUN bundle install --without development test rmagick

# Go back to app directory
WORKDIR /app

# Patch the PostgreSQL adapter AFTER all bundle installs are complete
# This ensures the gem won't be reinstalled and the patch won't be lost
RUN sed -i "902s/'panic'/'error'/" /usr/local/bundle/gems/activerecord-3.2.13/lib/active_record/connection_adapters/postgresql_adapter.rb

# Verify the patch was applied and show the result
RUN echo "=== Verifying PostgreSQL adapter patch ===" && \
    grep -n "client_min_messages" /usr/local/bundle/gems/activerecord-3.2.13/lib/active_record/connection_adapters/postgresql_adapter.rb | grep -E "(error|panic)" && \
    echo "=== Patch verification complete ==="

EXPOSE 3010
CMD ["sh", "-c", "echo 'Starting Rails application...' && echo 'PORT='${PORT:-3010} && echo 'DATABASE_URL='$DATABASE_URL && echo 'Checking preinitializer...' && cat config/preinitializer.rb && echo 'Running bundle exec...' && bundle exec rails server -b 0.0.0.0 -p ${PORT:-3010} 2>&1 || (echo 'Rails server failed with exit code:' $? && tail -100 log/production.log 2>/dev/null && sleep 30)"]
