module CacheBar
  module DataStore
    class Memcached < AbstractDataStore

      def backup_key_name
        "api-cache:backup:#{api_name}:#{uri_hash}"
      end

      def response_body_exists?
        client.get(cache_key_name) != nil
      end
      
      def get_response_body
        client.get(cache_key_name)
      end
      
      def store_response_body(response_body, interval)
        client.set(cache_key_name, response_body, interval)
      end
      
      def backup_exists?
        client.get(backup_key_name) != nil
      end
      
      def get_backup
        client.get(backup_key_name)
      end
      
      def store_backup(response_body)
        client.set(backup_key_name, response_body)
      end
    end
  end
end