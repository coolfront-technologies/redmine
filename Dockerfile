FROM ruby:2.3

# Fix Debian Stretch archived repositories
RUN sed -i 's|deb.debian.org|archive.debian.org|g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org|g' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99ignore-validation

RUN apt-get update && apt-get install -y \
      build-essential \
      libpq-dev \
      libxml2-dev \
      libxslt1-dev \
      libmagickwand-dev \
      libmagickcore-dev \
      git \
      curl \
      gnupg2 && \
    # Add PostgreSQL apt repository for newer libpq
    echo "deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt-get update && \
    apt-get install -y libpq5 libpq-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Gemfiles first (better layer caching)
COPY Gemfile Gemfile.lock ./
COPY plugins/redmine_s3/Gemfile plugins/redmine_s3/Gemfile
COPY plugins/redmine_s3/Gemfile.lock plugins/redmine_s3/Gemfile.lock

# Install Bundler compatible with Ruby 2.3
RUN gem install bundler -v 1.17.3

# Disable SSL verification (Ruby 2.3 + modern SSL workaround)
RUN bundle config set --local ssl_verify_mode 0

# Install main app gems
RUN bundle install --without development test rmagick

# Install plugin gems
WORKDIR /app/plugins/redmine_s3
RUN bundle install --without development test rmagick

WORKDIR /app

# Copy the rest of the application
COPY . .

EXPOSE 3010
CMD ["rails", "server", "-b", "0.0.0.0"]