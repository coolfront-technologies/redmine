# frozen_string_literal: true

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Force Rails to recognize HTTPS requests behind Azure proxy
  class Rack::Request
    def ssl?
      @env['HTTP_X_FORWARDED_PROTO'] == 'https' || @env['HTTPS'] == 'on'
    end
  end

  # Trust Azure / reverse-proxy forwarded headers
  config.action_dispatch.trusted_proxies = [%r{.*}]

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot.
  config.eager_load = true

  # Log to STDOUT for Docker/Azure
  config.logger = Logger.new($stdout)
  config.log_level = :info

  config.cache_store = :memory_store

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  config.action_mailer.raise_delivery_errors = true

  config.active_support.deprecation = :log

  ActionMailer::Base.smtp_settings = {
    :address        => 'smtp.sendgrid.net',
    :port           => '587',
    :authentication => :plain,
    :user_name      => ENV['SENDGRID_USERNAME'],
    :password       => ENV['SENDGRID_PASSWORD'],
    :domain         => 'heroku.com'
  }
  ActionMailer::Base.delivery_method = :smtp
end
