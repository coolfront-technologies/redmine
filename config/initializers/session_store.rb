# Use memory cache for sessions - avoids all cookie issues
RedmineApp::Application.config.session_store :cache_store,
  key: '_redmine_session',
  expire_after: 1.day