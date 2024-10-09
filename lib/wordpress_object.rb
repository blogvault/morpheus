require 'redis'
require 'json'

class WordPressObject
	def initialize(redis_client)
		@redis = redis_client
	end

	def store_object(type, slug, data)
		key = "#{type}:#{slug}"
		existing_data = @redis.get(key)

		if existing_data
			existing_array = JSON.parse(existing_data)
			insert_or_update_entry(existing_array, data)
			@redis.set(key, existing_array.to_json)
		else
			@redis.set(key, [data].to_json)
		end
	end

	def get_object(type, slug)
		key = "#{type}:#{slug}"
		data = @redis.get(key)
		data ? JSON.parse(data) : nil
	end

	def get_latest_object(type, slug)
		data = get_object(type, slug)
		data&.first
	end

	def get_keys(key)
		@redis.keys(key)
	end

	def get_object_by_version(type, slug, version)
		data = get_object(type, slug)
		data&.find { |obj| obj['version'] == version }
	end

	def get_objects_by_last_updated(type, slug, last_updated)
		key = "#{type}:#{slug}"

		data = JSON.parse(@redis.get(key))
		matching_entry = data.find { |entry| entry['last_updated'] == last_updated }

		matching_entry
	end

	def delete_object(type, slug)
		key = "#{type}:#{slug}"
		@redis.del(key)
	end

	def update_object(type, slug, new_data)
		key = "#{type}:#{slug}"
		existing_data = @redis.get(key)

		if existing_data
			existing_array = JSON.parse(existing_data)
			insert_or_update_entry(existing_array, new_data)
			@redis.set(key, existing_array.to_json)
		else
			@redis.set(key, [new_data].to_json)
		end
	end

	def reduce_entries_by_count(type, slug, max_count)
		key = "#{type}:#{slug}"
		existing_data = @redis.get(key)

		if existing_data
			existing_array = JSON.parse(existing_data)
			reduced_array = existing_array.take(max_count)
			@redis.set(key, reduced_array.to_json)
		end
	end

	def reduce_entries_by_expiry(type, slug, expiry_time, min_entries)
		key = "#{type}:#{slug}"
		existing_data = @redis.get(key)

		if existing_data
			existing_array = JSON.parse(existing_data)
			reduced_array = existing_array.sort_by { |entry| entry['last_updated'] }.reverse
			reduced_array = reduced_array.take([min_entries, reduced_array.size].max)
			reduced_array.reject! { |entry| Time.parse(entry['last_updated']) < expiry_time } if reduced_array.size > min_entries
			@redis.set(key, reduced_array.to_json)
		end
	end

	private

	def insert_or_update_entry(array, new_entry)
		index = array.index { |entry| entry['last_updated'] == new_entry['last_updated'] }
		if index
			array[index].merge!(new_entry)
		else
			array.unshift(new_entry)
			array.sort_by! { |entry| entry['last_updated'] }.reverse!
		end
	end
end

