FROM --platform=linux/amd64 debian:jessie

LABEL maintainer="you@example.com"
LABEL description="Legacy Ruby 2.0 Rails app for Azure deployment"

# --------------------------------------------------------------------
# Fix broken Jessie repos + disable GPG validation
# --------------------------------------------------------------------
RUN sed -i 's|http://deb.debian.org|http://archive.debian.org|g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org|g' /etc/apt/sources.list && \
    sed -i '/jessie-updates/d' /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "0";' > /etc/apt/apt.conf.d/99ignore-validation && \
    echo 'Acquire::AllowInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99ignore-validation && \
    apt-get -o Acquire::AllowInsecureRepositories=true update && \
    apt-get -y --allow-unauthenticated --force-yes install \
      build-essential \
      curl \
      git \
      libssl-dev \
      libreadline-dev \
      zlib1g-dev \
      libpq-dev \
      libmysqlclient-dev \
      imagemagick \
      libmagickwand-dev \
      libmagickcore-dev \
      libxml2-dev \
      libxslt1-dev \
      pkg-config \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# --------------------------------------------------------------------
# Build Ruby 2.0.0-p648 (final stable Ruby 2.0 release)
# --------------------------------------------------------------------
RUN curl -fsSL https://cache.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p648.tar.gz -o ruby.tar.gz && \
    tar -xzf ruby.tar.gz && cd ruby-2.0.0-p648 && \
    ./configure && make && make install && \
    cd .. && rm -rf ruby-2.0.0-p648 ruby.tar.gz

# Check Ruby
RUN ruby -v

# --------------------------------------------------------------------
# Install Bundler compatible with Ruby 2.0
# --------------------------------------------------------------------
RUN gem install bundler -v 1.17.3

# --------------------------------------------------------------------
# Set working directory
# --------------------------------------------------------------------
WORKDIR /app

# Copy Gemfiles first (for caching)
COPY Gemfile Gemfile.lock ./
COPY plugins/redmine_s3/Gemfile plugins/redmine_s3/Gemfile
COPY plugins/redmine_s3/Gemfile.lock plugins/redmine_s3/Gemfile.lock

# --------------------------------------------------------------------
# Allow legacy SSL and HTTP sources for RubyGems
# --------------------------------------------------------------------
RUN bundle config set --local disable_multisource true && \
    bundle config set --local ssl_verify_mode 0 && \
    bundle config mirror.https://rubygems.org http://rubygems.org

# --------------------------------------------------------------------
# Pre-install RMagick to avoid runtime missing gem error
# --------------------------------------------------------------------
RUN gem install rmagick -v 2.16.0 -- --with-opt-dir=/usr

# --------------------------------------------------------------------
# Install gems for main app (include all, skip only dev/test)
# --------------------------------------------------------------------
RUN bundle install --without development test

# Install gems for plugin
WORKDIR /app/plugins/redmine_s3
RUN bundle install --without development test

# --------------------------------------------------------------------
# Copy rest of the app
# --------------------------------------------------------------------
WORKDIR /app
COPY . .

# Expose Rails port
EXPOSE 3010

# --------------------------------------------------------------------
# Start the server
# --------------------------------------------------------------------
CMD ["rails", "server", "-b", "0.0.0.0"]
