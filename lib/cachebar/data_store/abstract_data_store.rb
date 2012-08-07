module CacheBar
  module DataStore
    class AbstractDataStore
      class_attribute :client

      attr_reader :api_name, :uri_hash
      
      def initialize(api_name, uri_hash)
        @api_name = api_name
        @uri_hash = uri_hash
      end
      
      def response_body_exists?
        raise NotImplementedError, 'Implement response_body_exists? in sub-class'
      end
      
      def get_response_body
        raise NotImplementedError, 'Implement get_response_body in sub-class'
      end
      
      def store_response_body(response_body, interval)
        raise NotImplementedError, 'Implement store_response_body in sub-class'
      end
      
      def backup_exists?
        raise NotImplementedError, 'Implement backup_exists? in sub-class'
      end
      
      def get_backup
        raise NotImplementedError, 'Implement get_backup in sub-class'
      end
      
      def store_backup(response_body)
        raise NotImplementedError, 'Implement store_backup in sub-class'
      end
      
      private 
      
      def cache_key_name
        "api-cache:#{api_name}:#{uri_hash}"
      end
      
      def backup_key_name
        "api-cache:#{api_name}"
      end
    end
  end
end