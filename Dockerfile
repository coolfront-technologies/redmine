FROM ruby:2.0

# Fix outdated Jessie repositories
RUN sed -i 's/httpredir.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i '/jessie-updates/d' /etc/apt/sources.list && \
    sed -i '/updates/d' /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "0";' > /etc/apt/apt.conf.d/99ignore-validation && \
    echo 'Acquire::AllowInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99ignore-validation && \
    echo 'Acquire::AllowDowngradeToInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99ignore-validation

RUN apt-get update -o Acquire::AllowInsecureRepositories=true \
    -o Acquire::AllowDowngradeToInsecureRepositories=true && \
    apt-get install -y --allow-unauthenticated \
      build-essential \
      libpq-dev \
      libmysqlclient-dev \
      imagemagick \
      libmagickwand-dev \
      libmagickcore-dev \
      git \
      curl

WORKDIR /app

# Copy main Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Copy plugin Gemfile and Gemfile.lock
COPY plugins/redmine_s3/Gemfile plugins/redmine_s3/Gemfile
COPY plugins/redmine_s3/Gemfile.lock plugins/redmine_s3/Gemfile.lock

# Install Bundler
RUN gem install bundler -v 1.17.3

# Disable SSL verification for legacy Ruby
RUN bundle config set --local ssl_verify_mode 0

# Install main app gems
RUN bundle install --without development test rmagick

# Install plugin gems
WORKDIR /app/plugins/redmine_s3
RUN bundle install --without development test rmagick

# Go back to app directory
WORKDIR /app

# Copy the rest of your app
COPY . .

EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]
