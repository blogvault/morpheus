require './config/initializers/config'

Sidekiq.configure_server do |config|
  config.redis = { url: CONFIG['redis']['url'] }
end

Sidekiq.configure_client do |config|
  config.redis = { url: CONFIG['redis']['url'] }
end
