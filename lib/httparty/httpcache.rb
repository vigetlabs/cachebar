module HTTParty
  module HTTPCache
    class NoResponseError < StandardError; end

    mattr_accessor  :perform_caching, 
                    :apis,
                    :logger, 
                    :redis,
                    :timeout_length, 
                    :cache_stale_backup_time,
                    :exception_callback

    mattr_reader :data_store_class

    self.perform_caching = false
    self.apis = {}
    self.timeout_length = 5 # 5 seconds
    self.cache_stale_backup_time = 300 # 5 minutes

    delegate :response_body_exists?,
             :get_response_body,
             :backup_exists?,
             :get_backup,
             :store_backup,
             :to => :data_store

    def self.included(base)
      base.class_eval do
        alias_method_chain :perform, :caching
      end
    end

    def self.data_store_class=(data_store_name_or_class)
      case data_store_name_or_class
      when Symbol
        require "cachebar/data_store/#{data_store_name_or_class}"
        @@data_store_class = CacheBar::DataStore.const_get(data_store_name_or_class.to_s.camelcase.to_sym)
      when Class
        @@data_store_class = data_store_name_or_class
      else
        raise ArgumentError, "data store must be a symbol or a class"
      end
    end

    def perform_with_caching
      if cacheable?
        if response_body_exists?
          log_message("Retrieving response from cache")
          response_from(get_response_body)
        else
          validate
          begin
            httparty_response = timeout(timeout_length) do
              perform_without_caching
            end
            httparty_response.parsed_response
            if httparty_response.response.is_a?(Net::HTTPSuccess)
              log_message("Storing good response in cache")
              store_in_cache(httparty_response.body)
              store_backup(httparty_response.body)
              httparty_response
            else
              retrieve_and_store_backup(httparty_response)
            end
          rescue *exceptions => e
            if exception_callback && exception_callback.respond_to?(:call)
              exception_callback.call(e, api_key_name, normalized_uri)
            end
            retrieve_and_store_backup
          end
        end
      else
        log_message("Caching off")
        perform_without_caching
      end
    end

    protected
    
    def cacheable?
      HTTPCache.perform_caching && HTTPCache.apis.keys.include?(uri.host) &&
        http_method == Net::HTTP::Get
    end

    def response_from(response_body)
      HTTParty::Response.new(self, OpenStruct.new(:body => response_body), lambda {parse_response(response_body)})
    end

    def retrieve_and_store_backup(httparty_response = nil)
      if backup_exists?
        log_message('using backup')
        response_body = get_backup
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

    def uri_hash
      @uri_hash ||= Digest::MD5.hexdigest(normalized_uri)
    end

    def store_in_cache(response_body, expires = nil)
      data_store.store_response_body(response_body, (expires || HTTPCache.apis[uri.host][:expire_in]))
    end

    def data_store
      @data_store ||= data_store_class.new(api_key_name, uri_hash)
    end
    
    def api_key_name
      HTTPCache.apis[uri.host][:key_name]
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
