<?php
/*
Plugin Name: WP Morpheus
Description: Redirects WordPress core, plugin, and theme updates to a mirror when wp.org is not reachable.
Version: 1.0
Author: Blogvault
Author URI: https://blogvault.net
*/

if (!defined('ABSPATH')) {
    exit;
}

class WP_Morpheus {
    private $mirror_url = 'https://morpheus.blogvault.net';

    public function __construct() {
        add_filter('pre_set_site_transient_update_core', array($this, 'check_core_updates'), 10, 2);
        add_filter('pre_set_site_transient_update_plugins', array($this, 'check_plugin_updates'), 10, 2);
        add_filter('pre_set_site_transient_update_themes', array($this, 'check_theme_updates'), 10, 2);
    }

		public function check_core_updates($transient, $transient_name) {
			if (!is_object($transient)) {
				$transient = new stdClass();
			}

			if (!isset($transient->updates)) {
				$transient->updates = array();
			}

			global $wp_version;
			$locale = get_locale();
			$payload = array(
				'version' => $wp_version,
				'locale' => $locale,
				'php' => phpversion(),
				'mysql' => $GLOBALS['wpdb']->db_version(),
				'all' => true
			);

			$response = $this->make_api_request('/core/version-check/1.7/', 'POST', $payload);

			if ($response && isset($response['offers'])) {
				foreach ($response['offers'] as $offer) {
					$transient->updates[] = json_decode(json_encode($offer));
				}
			}

			return $transient;
		}

		public function check_plugin_updates($transient, $transient_name) {
			if (!is_object($transient)) {
				$transient = new stdClass();
			}

			if (!isset($transient->response)) {
				$transient->response = array();
			}

			$plugins = get_plugins();
			$active_plugins = get_option('active_plugins');

			$payload = array(
				'plugins' => json_encode(array('plugins' => $plugins, 'active' => $active_plugins)),
				'translations' => json_encode(wp_get_installed_translations('plugins')),
				'locale' => json_encode(array(get_locale())),
				'all' => json_encode(true)
			);

			$response = $this->make_api_request('/plugins/update-check/1.1/', 'POST', $payload);

			if ($response && isset($response['plugins'])) {
				foreach ($response['plugins'] as $plugin_slug => $plugin_data) {
					// Continue if $plugin_data is an empty array
					if (empty($plugin_data)) {
						continue;
					}

					// If plugin is already in transient->response (WordPress update data)
					if (isset($transient->response[$plugin_slug])) {
						$wp_version = $transient->response[$plugin_slug]->new_version;
						$server_version = $plugin_data['new_version']; // Get version from your server

						// Continue if server version is empty
						if (empty($server_version)) {
							continue;
						}

						// Skip if WordPress version is greater than or equal to the server version
						if (!empty($wp_version) && version_compare($server_version, $wp_version, '<=')) {
							continue;
						}
					}

					// Convert plugin_data array to stdClass object
					$plugin_data_object = json_decode(json_encode($plugin_data));

					// Add the plugin to transient->response
					$transient->response[$plugin_slug] = $plugin_data_object;
				}

				// Handle translations and no_update
				if (isset($response['translations']) && is_array($response['translations'])) {
					$transient->translations = $response['translations'];
				}
				if (isset($response['no_update']) && is_array($response['no_update'])) {
					$transient->no_update = $response['no_update'];
				}
			}

			return $transient;
		}

		public function check_theme_updates($transient, $transient_name) {
			if (!is_object($transient)) {
				$transient = new stdClass();
			}

			if (!isset($transient->response)) {
				$transient->response = array();
			}

			$themes = wp_get_themes(); // Get all themes, but we will not send the active theme in the payload

			$payload = array(
				'themes' => json_encode(array('themes' => $themes)),
				'translations' => json_encode(wp_get_installed_translations('themes')),
				'locale' => json_encode(array(get_locale())),
				'all' => json_encode(true)
			);

			$response = $this->make_api_request('/themes/update-check/1.1/', 'POST', $payload);

			if ($response && isset($response['themes'])) {
				foreach ($response['themes'] as $theme_slug => $theme_data) {
					// Continue if $theme_data is an empty array
					if (empty($theme_data)) {
						continue;
					}
					// If theme is already in transient->response (WordPress update data)
					if (isset($transient->response[$theme_slug])) {
						$wp_version = $transient->response[$theme_slug]['new_version'];
						$server_version = $theme_data['new_version']; // Get version from your server

						// Continue if server version is empty
						if (empty($server_version)) {
							continue;
						}

						// Skip if WordPress version is greater than or equal to the server version
						if (!empty($wp_version) && version_compare($server_version, $wp_version, '<=')) {
							continue;
						}
					}

					// Add the theme to transient->response
					$transient->response[$theme_slug] = $theme_data;
				}

				// Handle translations and no_update
				if (isset($response['translations']) && is_array($response['translations'])) {
					$transient->translations = $response['translations'];
				}
				if (isset($response['no_update']) && is_array($response['no_update'])) {
					$transient->no_update = $response['no_update'];
				}
			}

			return $transient;
		}

		private function make_api_request($endpoint, $method = 'GET', $body = null) {
			$args = array(
				'timeout' => 30,
				'method' => $method,
			);

			if ($body) {
				$args['body'] = $body;
			}

			$response = wp_remote_request($this->mirror_url . $endpoint, $args);

			if (is_wp_error($response)) {
				return false;
			}

			$body = wp_remote_retrieve_body($response);
			return json_decode($body, true);
		}
}

new WP_Morpheus();