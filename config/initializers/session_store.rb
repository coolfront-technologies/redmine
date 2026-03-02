# Explicitly set the session store for Redmine
#RedmineApp::Application.config.session_store :cookie_store, key: '_redmine_session', domain: :all, secure: true, same_site: :none
Rails.application.config.session_store :cookie_store, key: '_redmine_session', domain: nil, secure: false