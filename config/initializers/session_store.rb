# Session configuration - secure:false because SSL terminates at Azure proxy
# Match Heroku's session configuration
RedmineApp::Application.config.session_store :cookie_store,
  key: '_redmine_session',
  expire_after: 1.day,
  secure: Rails.env.production? ? false : false,  # SSL terminates at proxy
  httponly: true