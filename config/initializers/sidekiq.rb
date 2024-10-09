require './config/initializers/config'

#LOGGER
sidekiq_logger = Logger.new('./log/sidekiq.log')

Sidekiq.configure_server do |config|
	config.redis = { url: CONFIG['redis']['url'] }
	config.logger = sidekiq_logger
end

Sidekiq.configure_client do |config|
  config.redis = { url: CONFIG['redis']['url'] }
	config.logger = sidekiq_logger
end
