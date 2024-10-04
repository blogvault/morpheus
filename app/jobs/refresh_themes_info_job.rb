require 'net/http'
require 'json'
require './lib/wordpress_api_client'

class RefreshThemesInfoJob
  include Sidekiq::Job

  def perform
    client = WordPressAPIClient.new(CONFIG['data_fetch_domain'], CONFIG['user_agent'])
    themes = fetch_all_themes(client)
    process_themes(themes)
  end

  private

  # Function to fetch all themes
  def fetch_all_themes(client)
    themes = []
    per_page = 100
    page = 1

    loop do
      # Construct the params for the API request
      params = {
        action: 'query_themes',
        request: {
          per_page: per_page,
          page: page
        }
      }

      # Make the API request using the WordPressAPIClient
      data = client.make_request('themes/info/1.2/', :get, params)

      break if data['themes'].nil? || data['themes'].empty?

      themes.concat(data['themes'])

      # Break if we've fetched all pages
      break if page >= data['info']['pages']

			process_themes(themes)
			themes = []
      page += 1
      sleep 1 # Be nice to the API
    end

    themes
  end

  def process_themes(themes)
    themes.each do |theme|
      # Enqueue ProcessUpdateQueueJob for each theme
      ProcessUpdateQueueJob.perform_async('theme', theme)
    end
  end
end

