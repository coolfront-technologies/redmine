# This file is used by Rack-based servers to start the application.

class AzureCookieFix
  def initialize(app)
    @app = app
  end

  def call(env)
    if env['HTTP_X_FORWARDED_PROTO'] == 'https'
      env['HTTPS'] = 'on'
      env['rack.url_scheme'] = 'https'
      env['SERVER_PORT'] = 443
    end

    status, headers, body = @app.call(env)

    if headers['Set-Cookie'] && env['HTTP_X_FORWARDED_PROTO'] == 'https'
      cookies = headers['Set-Cookie'].split("\n").map do |cookie|
        next cookie if cookie.include?('SameSite=')
        "#{cookie.strip}; SameSite=None; Secure"
      end
      headers['Set-Cookie'] = cookies.join("\n")
    end

    [status, headers, body]
  end
end

require ::File.expand_path('../config/environment', __FILE__)
use AzureCookieFix
run Rails.application
