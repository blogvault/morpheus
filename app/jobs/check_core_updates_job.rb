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
    process_core_updates(data['offers'], wp_object)
  end

  private

  def process_core_updates(offers, wp_object)
    offers.each do |offer|
      slug = offer['version'].split('.')[0..1].join('.')
      existing_data = wp_object.get_object('core', slug)

      unless existing_data&.first == offer
        ProcessUpdateQueueJob.perform_async('core', offer.merge('slug' => slug))
      end

      # Update latest WordPress release
      if offer['response'] == 'upgrade'
        REDIS.set('core:latest', offer.to_json)
      end
    end
  end
end

