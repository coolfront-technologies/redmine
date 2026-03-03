# Session configuration for Azure App Service
RedmineApp::Application.config.session_store :cookie_store,
  key: '_redmine_session',
  secure: false,
  httponly: true