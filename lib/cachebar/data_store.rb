module CacheBar
  module DataStore
    autoload :AbstractDataStore, 'cachebar/data_store/abstract_data_store'
    autoload :Redis, 'cachebar/data_store/redis'
  end
end
