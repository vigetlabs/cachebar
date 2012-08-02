require 'helper'

class TestCacheBar < Test::Unit::TestCase
  context 'CacheBar' do

    context 'mocking redis' do
      setup do
        @redis = mock
        HTTParty::HTTPCache.redis = @redis
      end

      context 'with caching on' do
        context 'with a good response' do
          setup do
            @uri_hash = '007a3a7aa28b11ef362040283e114f55'
            @response = fixture_file('user_timeline.json')
            VCR.insert_cassette('good_response')
          end

          teardown do
            VCR.eject_cassette
          end

          should "set key with expiration" do
            @redis.stubs(:exists).returns(false)
            @redis.expects(:set).with("api-cache:twitter:#{@uri_hash}", @response).returns(true)
            @redis.expects(:expire).with("api-cache:twitter:#{@uri_hash}", is_a(Integer)).returns(true)
            @redis.stubs(:hset).returns(true)
            TwitterAPI.user_timeline('viget')
          end

          should "store a backup" do
            @redis.stubs(:exists).returns(false)
            @redis.stubs(:set).returns(true)
            @redis.stubs(:expire).returns(true)
            @redis.expects(:hset).with('api-cache:twitter', @uri_hash, @response).returns(true)
            TwitterAPI.user_timeline('viget')
          end

          should 'return expected result to PIM class' do
            @redis.stubs(:exists).returns(false)
            @redis.stubs(:set).returns(true)
            @redis.stubs(:expire).returns(true)
            @redis.stubs(:hset).returns(true)
            tweets = TwitterAPI.user_timeline('viget')
            assert_kind_of Array, tweets.parsed_response
            assert tweets.parsed_response.present?
          end

          context 'and stored in cache' do
            should 'retrieve response from cache correctly' do
              @redis.stubs(:exists).returns(true)
              @redis.expects(:get).with("api-cache:twitter:#{@uri_hash}").returns(@response)
              tweets = TwitterAPI.user_timeline('viget')
              assert_kind_of Array, tweets.parsed_response
              assert tweets.parsed_response.present?
            end
          end
        end

        context 'with timeout' do
          setup do
            @uri_hash = '007a3a7aa28b11ef362040283e114f55'
            @response = fixture_file('user_timeline.json')
            HTTParty::Request.any_instance.expects(:timeout).raises(Timeout::Error)
          end

          should 'retrieve from backup if exists' do
            mock_response_in_backup(@uri_hash)
            response = TwitterAPI.user_timeline('viget')
            assert_kind_of Array, response.parsed_response
            assert response.parsed_response.present?
          end

          should 'raise NoResponseError error if no response in backup' do
            mock_no_response_in_backup(@uri_hash)
            assert_raise HTTParty::HTTPCache::NoResponseError do
              TwitterAPI.user_timeline('viget')
            end
          end
        end

        context 'with unparsable response' do
          setup do
            VCR.insert_cassette('unparsable')
            @uri_hash = '9780998e3ec445e5c0e56ca0bf10248c'
            @response = fixture_file('user_timeline.json')
          end

          should 'retrieve from backup if exists' do
            mock_response_in_backup(@uri_hash)
            response = TwitterAPI.bogus_resource
            assert_kind_of Array, response.parsed_response
            assert response.parsed_response.present?
          end

          should 'raise NoResponseError error if no response in backup' do
            mock_no_response_in_backup(@uri_hash)
            assert_raise HTTParty::HTTPCache::NoResponseError do
              TwitterAPI.bogus_resource
            end
          end

          should 'call exception callback if defined' do
            exception_callback = mock('exception_callback')
            exception_callback.expects(:call).with(instance_of(MultiJson::DecodeError), 'twitter', 'https://api.twitter.com/1/user_timeline.json').returns(true)
            HTTParty::HTTPCache.exception_callback = exception_callback
            mock_response_in_backup(@uri_hash)
            
            TwitterAPI.bogus_resource
            HTTParty::HTTPCache.exception_callback = nil
          end

          teardown do
            VCR.eject_cassette
          end
        end

        context 'with bad response' do
          setup do
            VCR.insert_cassette('bad_response')
            @uri_hash = '01cedaf99cbf9f7e585ac4fa034a4fd5'
            @response = fixture_file('user_timeline.json')
          end

          should 'retrieve from backup if exists' do
            mock_response_in_backup(@uri_hash)
            response = TwitterAPI.bogus_timeline('viget')
            assert_kind_of Array, response.parsed_response
            assert response.parsed_response.present?
          end

          should 'return bad response' do
            mock_no_response_in_backup(@uri_hash)
            response = TwitterAPI.bogus_timeline('viget')
            assert_equal 401, response.code
            assert !response.response.is_a?(Net::HTTPSuccess)
          end

          teardown do
            VCR.eject_cassette
          end
        end

        context 'with bad response exception' do
          setup do
            @uri_hash = '9780998e3ec445e5c0e56ca0bf10248c'
            @response = fixture_file('user_timeline.json')
          end

          should 'retrieve from backup if exists' do
            mock_response_in_backup(@uri_hash)
            mock_http_exception
            response = TwitterAPI.bogus_resource
            assert_kind_of Array, response.parsed_response
            assert response.parsed_response.present?
          end

          should 'raise NoResponseError error if no response in backup' do
            mock_no_response_in_backup(@uri_hash)
            mock_http_exception
            assert_raise HTTParty::HTTPCache::NoResponseError do
              TwitterAPI.bogus_resource
            end
          end
        end
      
        context 'with a post' do
          setup do
            VCR.insert_cassette('status_update_post')
          end
          
          should 'never try to cache' do
            @redis.expects(:exists).never
            @redis.expects(:set).never
            @redis.expects(:expires).never
            @redis.expects(:hset).never
            @redis.expects(:get).never
            TwitterAPI.update_status('viget', 'My new status.')
          end
          
          teardown do
            VCR.eject_cassette
          end
        end
      end

      context 'with caching off' do
        setup do
          turn_off_caching
          @redis.expects(:exists).never
          @uri_hash = '007a3a7aa28b11ef362040283e114f55'
          @response = fixture_file('user_timeline.json')
          VCR.insert_cassette('good_response')
        end

        should 'just return the response' do
          tweets = TwitterAPI.user_timeline('viget')
          assert_kind_of Array, tweets.parsed_response
          assert tweets.parsed_response.present?
        end

        teardown do
          VCR.eject_cassette
          turn_on_caching
        end
      end
    end

    context 'connecting to redis' do
      setup do
        VCR.insert_cassette('good_response')

        redis = Redis.new(:host => 'localhost', :port => 6379,
          :thread_safe => true, :db => '3')
        @redis = Redis::Namespace.new('httpcache', :redis => redis)
        HTTParty::HTTPCache.redis = @redis

        @redis.keys("api-cache*").each do |key|
          @redis.del(key)
        end
      end

      should "store its response in the cache" do
        assert_difference "@redis.keys('api-cache:twitter:*').count", 1 do
          TwitterAPI.user_timeline('viget')
        end
      end

      should "store a backup of its response" do
        assert_difference "@redis.hkeys('api-cache:twitter').count", 1 do
          TwitterAPI.user_timeline('viget')
        end
      end

      teardown do
        VCR.eject_cassette
        @redis.keys("api-cache*").each do |key|
          @redis.del(key)
        end
      end
    end

  end
end
