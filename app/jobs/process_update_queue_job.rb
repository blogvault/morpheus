require 'net/http'
require 'uri'
require './lib/wordpress_object'
require './lib/downloaded_files'
require 'byebug'

class ProcessUpdateQueueJob
	include Sidekiq::Job

	def perform(type, item)
		wp_object = WordPressObject.new(REDIS)
		downloaded_files = DownloadedFiles.new(CONFIG['storage_path'])

		type = determine_type(type)
		slug = item['slug']
		download_url = get_download_link(type, item)
		filename = File.basename(URI.parse(download_url).path)

		download_and_store_file(downloaded_files, type, slug, filename, download_url)

		item = update_download_links(type, item, slug, filename)
		item = update_core_packages(type, slug, item, downloaded_files) if type == 'core'
		item = update_language_packs(type, slug, item, downloaded_files)

		wp_object.store_object(type, slug, item)
	end

	private

	def determine_type(type)
		%w[plugin theme core].include?(type) ? type : nil
	end

	def get_download_link(type, item)
		item['download_link'] ||
			(type == 'theme' ? "https://downloads.wordpress.org/theme/#{item["slug"]}.#{item["version"]}.zip" : item.dig("download"))
	end

	def download_file(url, limit = 10)
		raise 'Too many HTTP redirects' if limit == 0

		uri = URI(url)
		response = Net::HTTP.get_response(uri)

		case response
		when Net::HTTPSuccess then
			response.body
		when Net::HTTPRedirection then
			location = response['location']
			download_file(location, limit - 1)
		else
			response.value
		end
	end

	def download_and_store_file(downloaded_files, type, slug, filename, download_url)
		unless downloaded_files.retrieve_file(type, slug, filename)
			file_content = download_file(download_url)
			downloaded_files.store_file(type, slug, filename, file_content)
		end
	end

	def update_download_links(type, item, slug, filename)
		file_server_url = CONFIG['file_server_url']
		item['package'] = "#{file_server_url}/download/#{type}/#{slug}/#{filename}" if type != 'core'
		item['download'] = "#{file_server_url}/download/#{type}/#{slug}/#{filename}" if type == 'core'
		item
	end

	def update_core_packages(type, slug, item, downloaded_files)
		packages = item['packages'] || {}
		packages.each do |key, download_url|
			next unless download_url
			filename = File.basename(URI.parse(download_url).path)
			download_and_store_file(downloaded_files, type, slug, filename, download_url)
			item['packages'][key] = "#{CONFIG['file_server_url']}/download/#{type}/#{slug}/#{filename}"
		end

		item
	end

	def update_language_packs(type, slug, item, downloaded_files)
		(item["language_packs"] || []).each_with_index { |language_pack, index|
			filename = "#{language_pack['version']}_#{language_pack['language']}.zip"
			path = "translations/#{filename}"
			download_and_store_file(downloaded_files, type, slug, path, language_pack["package"])
			item["language_packs"][index]['package'] = "#{CONFIG['file_server_url']}/translation/#{type}/#{slug}/#{filename}"
		}

		item
	end
end

