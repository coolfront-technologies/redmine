# Settings specified here will take precedence over those in config/application.rb
RedmineApp::Application.configure do

  # Force Rails to recognize HTTPS requests behind Azure proxy
  class Rack::Request
    def ssl?
      @env['HTTP_X_FORWARDED_PROTO'] == 'https' || @env['HTTPS'] == 'on'
    end
  end

  # IMPORTANT: Trust Azure proxy to fix IP spoofing error
  config.action_dispatch.trusted_proxies = %r{.*}

  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests
  config.cache_classes = true

  # Log to STDOUT for Docker/Azure
  config.logger = Logger.new(STDOUT)
  config.logger.level = Logger::INFO

  # Enable memory cache for sessions
  config.cache_store = :memory_store

  #####
  # Customize the default logger (http://ruby-doc.org/core/classes/Logger.html)
  #
  # Use a different logger for distributed setups
  # config.logger        = SyslogLogger.new
  #
  # Rotate logs bigger than 1MB, keeps no more than 7 rotated logs around.
  # When setting a new Logger, make sure to set it's log level too.
  #
  # config.logger = Logger.new(config.log_path, 7, 1048576)
  # config.logger.level = Logger::INFO

  # Full error reports are disabled and caching is turned on
  config.action_controller.perform_caching = true

  # Enable serving of images, stylesheets, and javascripts from an asset server
  # config.action_controller.asset_host                  = "http://assets.example.com"

  # Disable delivery errors if you bad email addresses should just be ignored
  config.action_mailer.raise_delivery_errors = true

  # No email in production log
  # config.action_mailer.logger = nil

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
