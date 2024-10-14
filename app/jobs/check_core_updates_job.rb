require 'net/http'
require 'json'
require './lib/wordpress_api_client'
require './lib/wordpress_object'
require 'byebug'

class CheckCoreUpdatesJob
	include Sidekiq::Job

	def perform
		client = WordPressAPIClient.new(CONFIG['data_fetch_domain'], CONFIG['user_agent'])
		wp_object = WordPressObject.new(REDIS)

		data = client.make_request('core/version-check/1.7/', :get)
		process_core_updates(client, data['offers'], wp_object)
	end

	private

	def process_core_updates(client, offers, wp_object)
		offers.each do |offer|
			slug = offer['version']
			slug = 'latest'	if offer['response'] == 'upgrade'

			# https://api.wordpress.org/translations/core/1.0/?version=6.6.2
			translations = client.make_request("/translations/core/1.0/?version=#{offer['version']}", :get)
			offer.merge!('language_packs' => translations['translations']) if translations&.dig('translations').present?

			ProcessUpdateQueueJob.perform_async('core', offer.merge('slug' => slug))
		end
	end
end

