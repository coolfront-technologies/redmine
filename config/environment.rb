# Load the rails application
require File.expand_path('../application', __FILE__)

# Make sure there's no plugin in vendor/plugin before starting
# vendor_plugins_dir = File.join(Rails.root, "vendor", "plugins")
# if Dir.glob(File.join(vendor_plugins_dir, "*")).any?
#   $stderr.puts "Plugins in vendor/plugins (#{vendor_plugins_dir}) are no longer allowed. " +
#     "Please, put your Redmine plugins in the `plugins` directory at the root of your " +
#     "Redmine directory (#{File.join(Rails.root, "plugins")})"
#   exit 1
# end

# Force SSL and trust proxy headers
Redmine::Application.configure do
  config.force_ssl = false  # Azure handles SSL termination
  config.action_controller.forgery_protection_origin_check = false
end

# Initialize the rails application
RedmineApp::Application.initialize!
