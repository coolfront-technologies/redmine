# Explicitly set the session store for Redmine
RedmineApp::Application.config.session_store :cookie_store, key: '_redmine_session'
