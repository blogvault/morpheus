require 'net/http'
require 'json'
require 'yaml'

class CustomPluginManager
  def initialize(config_file_path)
    @config_file_path = config_file_path
    @custom_plugins = load_custom_plugins
  end

  def fetch_custom_plugins
    @custom_plugins.map do |plugin|
      case plugin['system']
      when 'github'
        fetch_github_plugin(plugin)
      else
        # Add support for other systems here
        nil
      end
    end.compact
  end

  private

  def load_custom_plugins
    YAML.load_file(@config_file_path)
  end

  def fetch_github_plugin(plugin)
    latest_release = fetch_github_release(plugin['owner'], plugin['repo'])
    return nil unless latest_release

    {
      'slug' => plugin['slug'],
      'version' => latest_release['tag_name'].gsub(/^v/, ''),
      'download_link' => latest_release['assets']&.first&.dig('browser_download_url') || latest_release['zipball_url'],
      'last_updated' => latest_release['published_at'],
      'custom' => true
    }
  end

  def fetch_github_release(owner, repo)
    uri = URI("https://api.github.com/repos/#{owner}/#{repo}/releases/latest")
    request = Net::HTTP::Get.new(uri)
    request['Accept'] = 'application/vnd.github.v3+json'

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(request)
    end

    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
end

