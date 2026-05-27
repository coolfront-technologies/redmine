# Optional subpath deploy (e.g. https://dev.example.com/redmine)
if ENV['REDMINE_RELATIVE_URL_ROOT'].present?
  Redmine::Utils.relative_url_root = ENV['REDMINE_RELATIVE_URL_ROOT']
end
