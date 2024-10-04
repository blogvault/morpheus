require './config/initializers/config'
require 'redis'

REDIS = Redis.new(url: CONFIG['redis']['url'])
