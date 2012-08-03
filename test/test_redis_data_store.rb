require 'helper'

# HTTParty::HTTPCache.data_store = :redis
# // HTTParty::HTTPCache.data_store = MyDataStore
# 
# CacheBar::DataStores::Redis.client = $redis


class TestRedisDataStore < Test::Unit::TestCase
  context 'CacheBar::DataStore::Redis' do
    should 'initialize with api_name and uri_hash' do
      redis = CacheBar::DataStore::Redis.new('api_name', 'uri_hash')
      assert_equal 'api_name', redis.api_name
      assert_equal 'uri_hash', redis.uri_hash
    end
    
    context 'an instance of' do
      setup do
        @client = mock
        CacheBar::DataStore::Redis.client = @client
        @redis = CacheBar::DataStore::Redis.new('twitter', 'URIHASH')
      end

      context '#response_body_exists?' do
        should 'return true if the resource is in redis' do
          @client.expects(:exists).with("api-cache:twitter:URIHASH").returns(true)
          assert @redis.response_body_exists?
        end

        should 'return false if the resource is in redis' do
          @client.expects(:exists).with("api-cache:twitter:URIHASH").returns(false)
          assert !@redis.response_body_exists?
        end
      end

      context '#get_response_body' do
        should "retrieve the response from the cache" do
          @client.expects(:get).with("api-cache:twitter:URIHASH").returns("RESPONSE_BODY")
          assert_equal "RESPONSE_BODY", @redis.get_response_body
        end
      end

      context '#store_response_body' do
        should "store data in redis" do
          @client.expects(:set).with("api-cache:twitter:URIHASH", "RESPONSE_BODY").returns(true)
          @client.stubs(:expire).returns(true)
          @redis.store_response_body("RESPONSE_BODY", 10)
        end

        should "set expires on cache key" do
          @client.stubs(:set).returns(true)
          @client.expects(:expire).with("api-cache:twitter:URIHASH", 10).returns(true)
          @redis.store_response_body("RESPONSE_BODY", 10)
        end
      end

      context '#backup_exists?' do
        should 'return true if the resource is in the redis backup hash' do
          @client.expects(:exists).with("api-cache:twitter").returns(true)
          @client.expects(:hexists).with("api-cache:twitter", "URIHASH").returns(true)
          assert @redis.backup_exists?
        end

        should 'return false if the resource is not in the redis backup hash' do
          @client.expects(:exists).with("api-cache:twitter").returns(true)
          @client.expects(:hexists).with("api-cache:twitter", "URIHASH").returns(false)
          assert !@redis.backup_exists?
        end

        should 'return false if the backup hash does not exist' do
          @client.expects(:exists).with("api-cache:twitter").returns(false)
          assert !@redis.backup_exists?
        end
      end

      context '#get_backup' do
        should 'retrieve the response body from the backup hash' do
          @client.expects(:hget).with("api-cache:twitter", "URIHASH").returns("RESPONSE_BODY")
          assert_equal "RESPONSE_BODY", @redis.get_backup
        end
      end

      context '#store_backup' do
        should 'store the response body in the backup hash' do
          @client.expects(:hset).with("api-cache:twitter", "URIHASH", "RESPONSE_BODY").returns(true)
          @redis.store_backup("RESPONSE_BODY")
        end
      end
    end
  end
end