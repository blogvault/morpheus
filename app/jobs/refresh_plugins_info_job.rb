require 'net/http'
require 'json'
require './app/jobs/process_update_queue_job'
require './lib/wordpress_api_client'

class RefreshPluginsInfoJob
	include Sidekiq::Worker

	def perform
		client = WordPressAPIClient.new(CONFIG['data_fetch_domain'], CONFIG['user_agent'])
		plugins = fetch_all_plugins(client)
		process_plugins(plugins)
	end

	private

	# Function to fetch all plugins
	def fetch_all_plugins(client)
		plugins = []
		per_page = 1000
		page = 1

		loop do
			# Construct the params for the API request
			params = {
				action: 'query_plugins',
				request: {
					per_page: per_page,
					page: page
				}
			}

			# Make the API request using the WordPressAPIClient
			data = client.make_request('plugins/info/1.2/', :get, params)

			plugins.concat(data['plugins'])

			# Break if we've fetched all pages
			break if page >= data['info']['pages']

			process_plugins(plugins)
			plugins = []

			page += 1
			sleep 1 # Be nice to the API
		end

		plugins
	end

	def process_plugins(plugins)
		plugins.each do |plugin|
			# Enqueue ProcessUpdateQueueJob for each plugin
			ProcessUpdateQueueJob.perform_async('plugin', plugin)
		end
	end
end

