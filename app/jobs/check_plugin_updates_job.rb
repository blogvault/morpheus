require 'net/http'
require 'json'
require './lib/wordpress_api_client'
require './lib/wordpress_object'

class CheckPluginUpdatesJob
	include Sidekiq::Job

	MAX_PAGES = 5
	PER_PAGE = 250

	def perform
		client = WordPressAPIClient.new(CONFIG['data_fetch_domain'], CONFIG['user_agent'])
		wp_object = WordPressObject.new(REDIS)
		last_match = REDIS.get('refresh:plugins:last_match')
		latest_plugin = nil

		(1..MAX_PAGES).each do |page|
			params = {
				action: 'query_plugins',
					request: {
					browse: 'updated',
					per_page: PER_PAGE,
					page: page
				}
			}
			data = client.make_request('plugins/info/1.2/', :get, params)
			latest_plugin = data['plugins'][0] if page == 1
			break unless process_plugins(data['plugins'], wp_object, last_match)
		end

		if latest_plugin
			REDIS.set('refresh:plugins:last_match', "#{latest_plugin['slug']}:#{latest_plugin['last_updated']}")
		end
	end

	private

	def process_plugins(plugins, wp_object, last_match)
		plugins.each do |plugin|
			slug = plugin['slug']

			return false if last_match == "#{slug}:#{plugin['last_updated']}"
			ProcessUpdateQueueJob.perform_async('plugin', plugin)
		end
		true
	end
end

