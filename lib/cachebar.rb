require 'ostruct'
require 'httparty'
require 'digest/md5'
require 'active_support'
require 'active_support/core_ext/module/aliasing'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/module/delegation'
if RUBY_VERSION.split('.')[1].to_i < 9
  begin
    require 'system_timer'
  rescue LoadError
    $stderr.puts "When running a Ruby version before 1.9 you should consider using SystemTimer with CacheBar"
  end
end
require 'httparty/httpcache'

module CacheBar
  autoload :DataStore, 'cachebar/data_store'

  def self.register_api_to_cache(host, options)
    raise ArgumentError, "You must provide a host that you are caching API responses for." if host.blank?

    missing_options = ([:expire_in, :key_name] - options.keys)
    if missing_options.present?
      raise(ArgumentError, "Missing some required options: #{missing_options.join(", ")}")
    end

    HTTParty::HTTPCache.apis[host] = options
  end

  module ClassMethods
    def caches_api_responses(options)
      host = if base_uri.present?
        URI.parse(base_uri).host
      else
        options.delete(:host)
      end
      CacheBar.register_api_to_cache(host, options)
    end
  end

end

HTTParty::ClassMethods.send(:include, CacheBar::ClassMethods)
HTTParty::Request.send(:include, HTTParty::HTTPCache)
