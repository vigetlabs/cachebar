module CacheBar
  module DataStore
    class Redis < AbstractDataStore
      def response_body_exists?
        client.exists(cache_key_name)
      end
      
      def get_response_body
        client.get(cache_key_name)
      end
      
      def store_response_body(response_body, interval)
        client.set(cache_key_name, response_body)
        client.expire(cache_key_name, interval)
      end
      
      def backup_exists?
        client.exists(backup_key_name) && client.hexists(backup_key_name, uri_hash)
      end
      
      def get_backup
        client.hget(backup_key_name, uri_hash)
      end
      
      def store_backup(response_body)
        client.hset(backup_key_name, uri_hash, response_body)
      end
    end
  end
end