# Configure logger to write to STDOUT for Docker/Azure
if Rails.env.production?
  logger = Logger.new(STDOUT)
  logger.level = Logger::INFO
  Rails.logger = logger
  Rails.application.config.logger = logger
end
