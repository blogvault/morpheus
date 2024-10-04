require 'net/http'
require 'json'
require './lib/wordpress_api_client'
require './lib/wordpress_object'

class CheckThemeUpdatesJob
  include Sidekiq::Job

  MAX_PAGES = 5
  PER_PAGE = 250

  def perform
    client = WordPressAPIClient.new(CONFIG['data_fetch_domain'], CONFIG['user_agent'])
    wp_object = WordPressObject.new(REDIS)
    last_match = REDIS.get('refresh:themes:last_match')

    (1..MAX_PAGES).each do |page|
      params = {
        action: 'query_themes',
        request: {
          browse: 'updated',
          per_page: PER_PAGE,
          page: page
        }
      }

      data = client.make_request('themes/info/1.2/', :get, params)
      break unless process_themes(data['themes'], wp_object, last_match)
    end
  end

  private

  def process_themes(themes, wp_object, last_match)
    themes.each do |theme|
      slug = theme['slug']
      existing_data = wp_object.get_object('theme', slug)

      if existing_data&.first == theme
        REDIS.set('refresh:themes:last_match', "#{slug}:#{theme['last_updated']}")
        return false if last_match == "#{slug}:#{theme['last_updated']}"
      else
        ProcessUpdateQueueJob.perform_async('theme', theme)
      end
    end
    true
  end
end

