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

# Download and install newer libpq manually
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