# CacheBar

[![Code Climate](https://codeclimate.com/github/vigetlabs/cachebar.png)](https://codeclimate.com/github/vigetlabs/cachebar)

CacheBar is a simple API caching layer built on top of Redis and HTTParty.

When a good request is made to the API through an HTTParty module or class configured to be cached, it caches the response body in Redis. The cache is set to expire in the configured length of time. All following identical requests use the cache in Redis. When the cache expires it will attempt to refill the cache with a new good response. If though the response that comes back is bad (there was timeout, a 404, or some other problem), then CacheBar will fetch a backup response we also store in Redis (in a separate non-expiring hash). When it pulls this backup response out it inserts it into the standard cache and sets it to expire in 5 minutes. This way we won't look for a new good response for another 5 minutes.

Using this gem does not mean that all your HTTParty modules and requests will be automatically cached. You will have to configure them on a case by case basis. This means you can have some APIs that are cached and others that aren't.

## Install

    gem install cachebar

If you're on Ruby 1.8 it is recommended that you also install the SystemTimer gem:

    gem install SystemTimer

### Inside a Rails/Rack app:

Add this to your Gemfile:

    gem 'SystemTimer', :platforms => :ruby_18
    gem 'cachebar'

Follow the instructions below for configuring CacheBar.

## Usage

Although you can use CacheBar in any type of application, the examples provided will be for using it inside a Rails application.

### 1. Configuring CacheBar

There's a few configuration options to CacheBar, the first is specifying a Redis connection to use.

If you have an initializer for defining your Redis connection already like this:

    REDIS_CONFIG = YAML.load_file(Rails.root+'config/redis.yml')[Rails.env].freeze
    redis = Redis.new(:host => REDIS_CONFIG['host'], :port => REDIS_CONFIG['port'],
      :thread_safe => true, :db => REDIS_CONFIG['db'])
    $redis = Redis::Namespace.new(REDIS_CONFIG['namespace'], :redis => redis)

Then you can just add this:

    HTTParty::HTTPCache.redis = $redis

You'll then also want to turn on caching in the appropriate environments. For instance you'll want to add this to `config/environments/production.rb`:

    HTTParty::HTTPCache.perform_caching = true

CacheBar can also log useful information to your log file if you configure a logger for it:

    HTTParty::HTTPCache.logger = Rails.logger

By default we use a timeout of 5 seconds on all requests, this can be configured like so:

    HTTParty::HTTPCache.timeout_length = 10 # seconds

By default when we fallback to using a backup response, we then hold off looking for a new fresh response for 5 minutes, this can be configured like so:

    HTTParty::HTTPCache.cache_stale_backup_time = 120 # 2 minutes

If you want to perform an action (say notify an error tracking service) when an exception happens while performing or processing a request you can specify a callback. The only requirement is that it responds to `call` and that `call` accepts 3 parameters. Those 3 in order will be the exception, the redis key name of the API, and the URL endpoint:

    HTTParty::HTTPCache.exception_callback = lambda { |exception, api_name, url|
      Airbrake.notify_or_ignore(exception, {
        :component => api_name,
        :url => url,
        :cgi_data => ENV
      })
    }


### 2. Configuring an HTTParty module or class

If you already have HTTParty included then you just need to use the `caches_api_responses` method to register that API for caching, and your done. The `caches_api_responses` takes a hash of options:

* `host`* *optional*:
  * This is used internally to decide which requests to try to cache responses for.
    If you've defined `base_uri` on the class/module that HTTParty is included into then this option is not needed.
* `key_name`:
  * This is the name used in Redis to create a part of the cache key to easily differentiate it from other API caches.
* `expire_in`:
  * This determines how long the good API responses are cached for.

Here's an example using Twitter:

    module TwitterAPI
      include HTTParty
      base_uri 'https://api.twitter.com/1'
      format :json

      caches_api_responses :key_name => "twitter", :expire_in => 3600
    end

After that all Twitter API calls will be cached for an hour.

If you want to cache an API that uses HTTParty but never includes HTTParty into a class or module, you can register the API like this:

    CacheBar.register_api_to_cache('api.example.com', {:key_name => "example", :expire_in => 7200})


## Contributing to CacheBar
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2011 Brian Landau. See LICENSE.txt for further details.
