#FROM ruby:2.0
FROM ruby:2.6.10

# Install build dependencies
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      libpq-dev \
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

# Copy main Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Copy plugin Gemfile and Gemfile.lock
COPY plugins/redmine_s3/Gemfile plugins/redmine_s3/Gemfile

# Install Bundler
RUN gem install bundler -v 1.17.3

# Install compatible versions first
RUN gem install json -v 2.6.3

# Install main app gems (exclude MySQL gems)
RUN bundle config set --local without 'development test rmagick'
RUN bundle install

# Install plugin gems
WORKDIR /app/plugins/redmine_s3
RUN rm -f Gemfile.lock
RUN bundle install --without development test rmagick

# Go back to app directory
WORKDIR /app

# Copy the rest of your app
COPY . .

EXPOSE 3010
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
