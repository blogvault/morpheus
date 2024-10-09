require 'fileutils'

class DownloadedFiles
	def initialize(storage_path)
		@storage_path = storage_path
		FileUtils.mkdir_p(@storage_path) unless Dir.exist?(@storage_path)
	end

	def store_file(type, slug, filename, file_content)
		file_path = file_path(type, slug, filename)
		FileUtils.mkdir_p(File.dirname(file_path))
		File.open(file_path, 'wb') do |file|
			file.write(file_content)
		end
	end

	def retrieve_file(type, slug, filename)
		file_path = file_path(type, slug, filename)
		File.read(file_path) if File.exist?(file_path)
	end

	def list_files(type, slug)
		dir_path = File.join(@storage_path, type, slug)
		if Dir.exist?(dir_path)
			Dir.glob(File.join(dir_path, '*')).map { |f| File.basename(f) }
		else
			[]
		end
	end

	def delete_file(type, slug, filename)
		file_path = file_path(type, slug, filename)
		File.delete(file_path) if File.exist?(file_path)
	end

	def delete_all_files(type, slug)
		dir_path = File.join(@storage_path, type, slug)
		FileUtils.rm_rf(dir_path) if Dir.exist?(dir_path)
	end

	private

	def file_path(type, slug, filename)
		File.join(@storage_path, type, slug, filename)
	end
end

