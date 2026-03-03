# Disable CSRF origin check for Azure proxy compatibility
# This is safe because Azure App Service is the only entry point
begin
  Rails.application.config.action_controller.forgery_protection_origin_check = false
rescue NoMethodError
  # Rails 3.2 doesn't have this option, skip it
end