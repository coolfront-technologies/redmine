# Completely disable CSRF protection for login
# Safe because Azure App Service is the only entry point

Rails.application.config.after_initialize do
  AccountController.class_eval do
    skip_before_filter :verify_authenticity_token, :only => [:login]
  end
end