require 'sinatra'
require 'sidekiq'
require 'sidekiq-cron'
require 'sidekiq/api'
require './config/initializers/config'
require './config/initializers/redis'

Dir[File.join(__dir__, 'app/jobs', '*.rb')].each { |file| require file }

require 'json'
require 'byebug'
require './lib/wordpress_object'
require './lib/wordpress_api_client'

Sidekiq::Cron::Job.load_from_hash({
  'RefreshPluginsInfoJob' => {
    'class' => 'RefreshPluginsInfoJob',
    'cron'  => '0 0 * * *',  # Runs once a day at midnight
    'queue' => 'default'
  },
  'RefreshThemesInfoJob' => {
    'class' => 'RefreshThemesInfoJob',
    'cron'  => '0 0 * * *',  # Runs once a day at midnight
    'queue' => 'default'
  },
  'CheckCoreUpdatesJob' => {
    'class' => 'CheckCoreUpdatesJob',
    'cron'  => '*/5 * * * *',  # Runs every 5 minutes
    'queue' => 'default'
  },
  'CheckThemeUpdatesJob' => {
    'class' => 'CheckThemeUpdatesJob',
    'cron'  => '*/5 * * * *',  # Runs every 5 minutes
    'queue' => 'default'
  },
  'CheckPluginUpdatesJob' => {
    'class' => 'CheckPluginUpdatesJob',
    'cron'  => '*/5 * * * *',  # Runs every 5 minutes
    'queue' => 'default'
  }
})

# Initialize Redis client and WordPress object
redis_client = Redis.new(url: CONFIG['redis']['url'])
wp_object = WordPressObject.new(redis_client)

# Helper method to validate and parse JSON input
def parse_json_body(_params)
  JSON.parse(_params)
rescue JSON::ParserError
  halt 400, { error: 'Invalid JSON' }.to_json
end

# Helper method to format plugin response
def format_plugin_response(plugin, file)
  {
    id: "w.org/plugins/#{plugin["slug"]}",
    slug: plugin['slug'],
    plugin: file,
    new_version: plugin['version'],
    url: "https://wordpress.org/plugins/#{plugin["slug"]}",
    package: plugin['package'],
    icons: plugin['icons'],
    banners: plugin['banners'],
    banners_rtl: plugin['banners_rtl'],
    requires: plugin['requires'],
    tested: plugin['tested'],
    requires_php: plugin['requires_php'],
    requires_plugins: plugin['requires_plugins'],
  }
end

# Helper method to format theme response
def format_theme_response(theme)
  {
    theme: theme['slug'],
    new_version: theme['version'],
    url: theme['homepage'],
    package: theme['package'],
    requires: theme['requires'],
    requires_php: theme['requires_php']
  }
end

# Helper method to format translation response
def format_translation_response(translation)
  {
    type: translation['type'],
    slug: translation['slug'],
    language: translation['language'],
    version: translation['version'],
    updated: translation['updated'],
    package: translation['package'],
    autoupdate: translation['autoupdate']
  }
end

# Check for Plugin Updates
# POST /plugins/update-check/1.1/
# @param plugins [Hash] Installed plugins with their versions
# @param translations [Array] Installed plugin translations
# @param locale [Array] Site locale
# @param all [String] Check all plugins flag
# @return [Hash] Available plugin updates and translations
post '/plugins/update-check/1.1/' do
  content_type :json
  data = parse_json_body(params["plugins"])

  # Validate input
  halt 400, { error: 'Invalid input' }.to_json unless data['plugins'].is_a?(Hash)

  response = { plugins: {}, no_update: [], translations: [] }

  data['plugins'].each do |plugin, info|
    stored_plugin = wp_object.get_latest_object('plugin', plugin.split('/').first)
    if stored_plugin && Gem::Version.new(stored_plugin['version']) > Gem::Version.new(info['Version'])
      response[:plugins][plugin] = format_plugin_response(stored_plugin, plugin)
    else
      response[:no_update] << plugin
    end
  end

  if data['translations']
    data['translations'].each do |translation|
      stored_translation = wp_object.get_object_by_version('plugin_translation', translation['slug'], translation['version'])
      response[:translations] << format_translation_response(stored_translation) if stored_translation
    end
  end

  response.to_json
end

# Check for Theme Updates
# POST /themes/update-check/1.1/
# @param themes [Hash] Installed themes with their versions
# @param translations [Array] Installed theme translations
# @param locale [Array] Site locale
# @param all [String] Check all themes flag
# @return [Hash] Available theme updates and translations
post '/themes/update-check/1.1/' do
  content_type :json
  data = parse_json_body(params["themes"])

  # Validate input
  halt 400, { error: 'Invalid input' }.to_json unless data['themes'].is_a?(Hash)

  response = { themes: {}, no_update: [], translations: [] }

  data['themes'].each do |theme, info|
    stored_theme = wp_object.get_latest_object('theme', theme)
    if stored_theme && Gem::Version.new(stored_theme['version']) > Gem::Version.new(info['Version'])
      response[:themes][theme] = format_theme_response(stored_theme)
    else
      response[:no_update] << theme
    end
  end

  if data['translations']
    data['translations'].each do |translation|
      stored_translation = wp_object.get_object_by_version('theme_translation', translation['slug'], translation['version'])
      response[:translations] << format_translation_response(stored_translation) if stored_translation
    end
  end

  response.to_json
end

# Check for Core Updates
# POST /core/version-check/1.7/
# @param version [String] Current WordPress version
# @param php [String] Current PHP version
# @param locale [String] Site's locale
# @param mysql [String] Current MySQL version
# @return [Hash] Available core updates and translations
post '/core/version-check/1.7/' do
  content_type :json
  data = params

  # Validate input
  required_params = %w[version php locale mysql]
  halt 400, { error: 'Missing required parameters' }.to_json unless required_params.all? { |param| data.key?(param) }

  current_version = Gem::Version.new(data['version'])
  response = { offers: [], translations: [] }

  # Get all core versions
	core_version_keys = wp_object.get_keys("core:*").map { |version_key| version_key.split(':').last }
	core_versions = core_version_keys.map { |version| wp_object.get_object('core', version) }.flatten

  core_versions.each do |version|
    if Gem::Version.new(version['version']) > current_version
      response[:offers] << {
        response: version["response"],
        download: version['download'],
        locale: version['locale'],
        packages: version['packages'],
        current: version['version'],
        version: version['version'],
        php_version: version['php_version'],
        mysql_version: version['mysql_version'],
        new_bundled: version['new_bundled'],
        partial_version: version['partial_version'],
        new_files: version['new_files']
      }
    end
  end

  # Get translations
  translations = wp_object.get_object('core_translation', data['locale'])
  response[:translations] = translations.map { |t| format_translation_response(t) } if translations

  response.to_json
end

# Route for downloading plugin files
get '/download/plugin/:plugin_name/:filename' do |plugin_name, filename|
  file_path = File.join(settings.public_folder, 'plugin', plugin_name, filename)

  if File.exist?(file_path)
    send_file file_path, :filename => "plugin_#{plugin_name}.zip", :type => 'Application/octet-stream'
  else
    halt 404, "File not found"
  end
end

# Route for downloading theme files
get '/download/theme/:theme_name/:filename' do |theme_name, filename|
  file_path = File.join(settings.public_folder, 'theme', theme_name, filename)

  if File.exist?(file_path)
    send_file file_path, :filename => "theme_#{theme_name}.zip", :type => 'Application/octet-stream'
  else
    halt 404, "File not found"
  end
end

# Route for downloading core files
get '/download/core/:core_version/:filename' do |core_version, filename|
  file_path = File.join(settings.public_folder, 'core', core_version, filename)

  if File.exist?(file_path)
    send_file file_path, :filename => "core_#{core_version}.zip", :type => 'Application/octet-stream'
  else
    halt 404, "File not found"
  end
end

