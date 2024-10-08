require 'net/http'
require 'json'
require 'uri'

class WordPressAPIClient
  MAX_RETRIES = 3
  RETRY_DELAY = 1 # second

  def initialize(base_url = 'https://api.wordpress.org/', user_agent = nil)
    @base_url = base_url
    @user_agent = user_agent
  end

  # Generic method to make API requests
  def make_request(endpoint, method = :get, params = {}, headers = {})
    uri = URI.join(@base_url, endpoint)

		if method == :get && !params.empty?
			uri.query = to_query_string(params).join('&')
		end

    retries = 0
    begin
      response = case method
                 when :get
                   get_request(uri, headers)
                 when :post
                   post_request(uri, params, headers)
                 else
                   raise ArgumentError, 'Unsupported HTTP method'
                 end

      handle_response(response)
    rescue SocketError, Net::HTTPError, Net::OpenTimeout, Net::ReadTimeout => e
      retries += 1
      if retries <= MAX_RETRIES
        sleep(RETRY_DELAY)
        retry
      else
        raise e
      end
    end
  end

  private

  def get_request(uri, headers)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      request = Net::HTTP::Get.new(uri)
      set_headers(request, headers)
      http.request(request)
    end
  end

  def post_request(uri, params, headers)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      request = Net::HTTP::Post.new(uri)
      set_headers(request, headers)
      request.set_form_data(params)
      http.request(request)
    end
  end

  def set_headers(request, headers)
    request['User-Agent'] = @user_agent if @user_agent
    headers.each { |key, value| request[key] = value }
  end

  # Handle API response
  def handle_response(response)
    case response
    when Net::HTTPSuccess
      JSON.parse(response.body)
    else
      raise Net::HTTPError.new('HTTP Error', response)
    end
  end

	def to_query_string(params, parent_key = nil)
		query_parts = []

		params.each do |key, value|
			# Create a full key, with nested structure if needed
			full_key = parent_key ? "#{parent_key}[#{key}]" : key.to_s

			if value.is_a?(Hash)
				# Recursive call for nested hashes
				query_parts.concat(to_query_string(value, full_key))
			else
				# Append the key-value pair to query parts
				query_parts << "#{full_key}=#{value}"
			end
		end

		query_parts
	end
end

