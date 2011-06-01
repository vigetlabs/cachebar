module TwitterAPI
  include HTTParty
  base_uri 'https://api.twitter.com/1'
  format :json

  caches_api_responses :key_name => "twitter", :expire_in => 3600

  class << self
    def user_timeline(username)
      get '/statuses/user_timeline.json', :query => {:screen_name => username}
    end

    def bogus_timeline(username)
      get '/statuses/bogus_timeline.json', :query => {:screen_name => username}
    end

    def bogus_resource
      get '/user_timeline.json'
    end
  end

end