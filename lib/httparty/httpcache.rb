module HTTParty
  module HTTPCache
    class NoResponseError < StandardError; end

    mattr_accessor  :perform_caching, 
                    :apis,
                    :logger, 
                    :redis,
                    :timeout_length, 
                    :cache_stale_backup_time

    self.perform_caching = false
    self.apis = {}
    self.timeout_length = 5 # 5 seconds
    self.cache_stale_backup_time = 300 # 5 minutes

    def self.included(base)
      base.class_eval do
        alias_method_chain :perform, :caching
      end
    end

    def perform_with_caching
      if HTTPCache.perform_caching && HTTPCache.apis.keys.include?(uri.host)
        if response_in_cache?
          log_message("Retrieving response from cache")
          response_from(response_body_from_cache)
        else
          begin
            httparty_response = timeout(timeout_length) do
              perform_without_caching
            end
            if httparty_response.response.is_a?(Net::HTTPSuccess)
              log_message("Storing good response in cache")
              store_in_cache(httparty_response.body)
              store_backup(httparty_response.body)
              httparty_response
            else
              retrieve_and_store_backup(httparty_response)
            end
          rescue *exceptions
            retrieve_and_store_backup
          end
        end
      else
        log_message("Caching off")
        perform_without_caching
      end
    end

    protected

    def response_from(response_body)
      HTTParty::Response.new(self, OpenStruct.new(:body => response_body), parse_response(response_body))
    end

    def retrieve_and_store_backup(httparty_response = nil)
      if backup_exists?
        log_message('using backup')
        response_body = backup_response
        store_in_cache(response_body, cache_stale_backup_time)
        response_from(response_body)
      elsif httparty_response
        httparty_response
      else
        log_message('No backup and bad response')
        raise NoResponseError, 'Bad response from API server or timeout occured and no backup was in the cache'
      end
    end

    def normalized_uri
      return @normalized_uri if @normalized_uri
      normalized_uri = uri.dup
      normalized_uri.query = sort_query_params(normalized_uri.query)
      normalized_uri.path.chop! if (normalized_uri.path =~ /\/$/)
      normalized_uri.scheme = normalized_uri.scheme.downcase
      @normalized_uri = normalized_uri.normalize.to_s
    end

    def sort_query_params(query)
      query.split('&').sort.join('&') unless query.blank?
    end

    def cache_key_name
      @cache_key_name ||= "api-cache:#{HTTPCache.apis[uri.host][:key_name]}:#{uri_hash}"
    end

    def uri_hash
      @uri_hash ||= Digest::MD5.hexdigest(normalized_uri)
    end

    def response_in_cache?
      redis.exists(cache_key_name)
    end

    def backup_key
      "api-cache:#{HTTPCache.apis[uri.host][:key_name]}"
    end

    def backup_response
      redis.hget(backup_key, uri_hash)
    end

    def backup_exists?
      redis.exists(backup_key) && redis.hexists(backup_key, uri_hash)
    end

    def response_body_from_cache
      redis.get(cache_key_name)
    end

    def store_in_cache(response_body, expires = nil)
      redis.set(cache_key_name, response_body)
      redis.expire(cache_key_name, (expires || HTTPCache.apis[uri.host][:expire_in]))
    end

    def store_backup(response_body)
      redis.hset(backup_key, uri_hash, response_body)
    end

    def log_message(message)
      logger.info("[HTTPCache]: #{message} for #{normalized_uri} - #{uri_hash.inspect}") if logger
    end

    def timeout(seconds, &block)
      if defined?(SystemTimer)
        SystemTimer.timeout_after(seconds, &block)
      else
        options[:timeout] = seconds
        yield
      end
    end

    def exceptions
      if (RUBY_VERSION.split('.')[1].to_i >= 9) && defined?(Psych::SyntaxError)
        [StandardError, Timeout::Error, Psych::SyntaxError]
      else
        [StandardError, Timeout::Error]
      end
    end
  end
end
