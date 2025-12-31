#FROM ruby:2.0
FROM ruby:2.7.8

# Fix outdated Jessie repositories
#RUN sed -i 's/httpredir.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
 #   sed -i 's/security.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
 #   sed -i '/jessie-updates/d' /etc/apt/sources.list && \
 #   sed -i '/updates/d' /etc/apt/sources.list && \
 #   echo 'Acquire::Check-Valid-Until "0";' > /etc/apt/apt.conf.d/99ignore-validation && \
 #   echo 'Acquire::AllowInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99ignore-validation && \
 #   echo 'Acquire::AllowDowngradeToInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99ignore-validation

#RUN apt-get update -o Acquire::AllowInsecureRepositories=true \
 #   -o Acquire::AllowDowngradeToInsecureRepositories=true && \
 #   apt-get install -y --allow-unauthenticated \
 #     build-essential \
 
 # Install build dependencies
 RUN apt-get update && \
    apt-get install -y \
      build-essential \
      default-libmysqlclient-dev \
      imagemagick \
      libmagickwand-dev \
      git \
      curl \
      wget \
      gnupg \
      lsb-release

# Add PostgreSQL 12 repository and install modern libpq
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt-get update && \
    apt-get install -y postgresql-client-12 libpq-dev && \
    rm -rf /var/lib/apt/lists/*

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

# Force newer json gem compatible with Ruby 2.7
RUN gem install json -v '2.6.3'

RUN bundle install --without development test rmagick

# Go back to app directory
WORKDIR /app

# Copy the rest of your app
COPY . .

EXPOSE 3010
CMD ["rails", "server", "-b", "0.0.0.0"]
