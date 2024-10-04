require 'json'
require 'sidekiq'
require 'sidekiq-cron'

require_relative 'config/initializers/config'
require_relative 'config/initializers/redis'
require_relative 'config/initializers/sidekiq'
require_relative 'lib/wordpress_object'
require_relative 'lib/wordpress_api_client'

Dir['app/jobs/*.rb'].each { |file| require_relative file }

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
