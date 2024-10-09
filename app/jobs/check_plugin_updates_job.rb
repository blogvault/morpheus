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
			break unless process_plugins(data['plugins'], wp_object, last_match)
		end
	end

	private

	def process_plugins(plugins, wp_object, last_match)
		plugins.each do |plugin|
			slug = plugin['slug']
			existing_data = wp_object.get_object('plugin', slug)

			if existing_data&.first == plugin
				REDIS.set('refresh:plugins:last_match', "#{slug}:#{plugin['last_updated']}")
				return false if last_match == "#{slug}:#{plugin['last_updated']}"
			else
				ProcessUpdateQueueJob.perform_async('plugin', plugin)
			end
		end
		true
	end
end

