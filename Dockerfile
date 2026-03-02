FROM ruby:2.3

# Fix Debian Stretch archived repositories
RUN sed -i 's|deb.debian.org|archive.debian.org|g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org|g' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99ignore-validation

RUN apt-get update -o Acquire::Check-Valid-Until=false && \
    apt-get install -y --allow-unauthenticated \
      build-essential \
      libpq-dev \
      default-libmysqlclient-dev \
      imagemagick \
      libmagickwand-dev \
      libmagickcore-dev \
      git \
      curl && \
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