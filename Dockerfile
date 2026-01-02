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

# Fix PostgreSQL adapter for modern PostgreSQL compatibility
RUN mkdir -p config/initializers && \
    echo "if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)" > config/initializers/postgresql_adapter_fix.rb && \
    echo "  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do" >> config/initializers/postgresql_adapter_fix.rb && \
    echo "    def client_min_messages=(level)" >> config/initializers/postgresql_adapter_fix.rb && \
    echo "      level = 'error' if level.to_s == 'panic'" >> config/initializers/postgresql_adapter_fix.rb && \
    echo "      execute(\"SET client_min_messages TO '#{level}'\", 'SCHEMA')" >> config/initializers/postgresql_adapter_fix.rb && \
    echo "    end" >> config/initializers/postgresql_adapter_fix.rb && \
    echo "  end" >> config/initializers/postgresql_adapter_fix.rb && \
    echo "end" >> config/initializers/postgresql_adapter_fix.rb
    
# Install main app gems (exclude MySQL gems)
RUN bundle install

# Install plugin gems
WORKDIR /app/plugins/redmine_s3
RUN bundle install --without development test rmagick

# Go back to app directory
WORKDIR /app

EXPOSE 3010
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
