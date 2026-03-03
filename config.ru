# This file is used by Rack-based servers to start the application.

# SameSite Cookie Middleware for Azure
class SameSiteCookies
  def initialize(app)
    @app = app
  end

  def call(env)
    # Set HTTPS flag for Rails
    env["HTTPS"] = "on" if env["HTTP_X_FORWARDED_PROTO"] == "https"
    env["rack.url_scheme"] = "https" if env["HTTP_X_FORWARDED_PROTO"] == "https"

    status, headers, body = @app.call(env)

    if headers["Set-Cookie"]
      cookies = headers["Set-Cookie"].is_a?(Array) ? headers["Set-Cookie"] : headers["Set-Cookie"].split("\n")
      cookies = cookies.map do |cookie|
        next cookie if cookie =~ /SameSite=/i
        cookie.strip + "; SameSite=None; Secure"
      end
      headers["Set-Cookie"] = cookies.join("\n")
    end

    [status, headers, body]
  end
end

# Load original Redmine application
require ::File.expand_path('../config/environment',  __FILE__)

# Wrap with SameSite middleware
use SameSiteCookies
run RedmineApp::Application
