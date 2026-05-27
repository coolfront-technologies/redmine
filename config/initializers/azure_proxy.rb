# Azure App Service / reverse-proxy: HTTPS detection and client IP
Rails.application.config.action_dispatch.trusted_proxies = [%r{.*}] if Rails.env.production?

if defined?(Rack::Request)
  class Rack::Request
    def ssl?
      @env['HTTP_X_FORWARDED_PROTO'] == 'https' ||
        @env['HTTP_X_ARR_SSL'].present? ||
        @env['HTTPS'] == 'on' ||
        @env['rack.url_scheme'] == 'https'
    end
  end
end
