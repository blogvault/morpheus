require 'sidekiq'
require './lib/custom_plugin_manager'
require './lib/wordpress_object'

class RefreshCustomPluginsJob
  include Sidekiq::Job

  def perform
    custom_plugin_manager = CustomPluginManager.new(CONFIG['custom_plugins']['file_path'])

    custom_plugins = custom_plugin_manager.fetch_custom_plugins

    custom_plugins.each do |plugin|
      wp_plugin = transform_to_wp_format(plugin)
      ProcessUpdateQueueJob.perform_async('plugin', wp_plugin)
    end
  end

  private

  def transform_to_wp_format(plugin)
    {
      'slug' => plugin['slug'],
      'version' => plugin['version'],
      'download_link' => plugin['download_link'],
      'last_updated' => plugin['last_updated'],
      'name' => plugin['slug'].capitalize,
      'author' => 'Custom Plugin',
      'author_profile' => '',
      'requires' => '',
      'tested' => '',
      'requires_php' => '',
      'rating' => 0,
      'num_ratings' => 0,
      'support_threads' => 0,
      'support_threads_resolved' => 0,
      'active_installs' => 0,
      'downloaded' => 0,
      'last_updated' => plugin['last_updated'],
      'added' => plugin['last_updated'],
      'homepage' => '',
      'sections' => {
        'description' => 'Custom plugin hosted externally.',
        'installation' => '',
        'faq' => '',
        'changelog' => '',
        'screenshots' => ''
      },
      'tags' => {},
      'donate_link' => '',
      'icons' => {
        '1x' => '',
        '2x' => ''
      },
      'banners' => {
        'low' => '',
        'high' => ''
      },
      'contributors' => {},
      'custom' => true
    }
  end
end

