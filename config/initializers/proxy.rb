# Trust Azure proxy headers
Rails.application.config.action_dispatch.trusted_proxies = /.*/ rescue nil