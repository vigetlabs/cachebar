require 'helper'

class TestMemcachedDataStore < Test::Unit::TestCase
  context 'CacheBar::DataStore::Memcached' do
    should 'initialize with api_name and uri_hash' do
      memcached = CacheBar::DataStore::Memcached.new('api_name', 'uri_hash')
      assert_equal 'api_name', memcached.api_name
      assert_equal 'uri_hash', memcached.uri_hash
    end

    context 'an instance of' do
      setup do
        @client = mock
        CacheBar::DataStore::Memcached.client = @client
        @memcached = CacheBar::DataStore::Memcached.new('twitter', 'URIHASH')
      end

      context '#response_body_exists?' do
        should 'return true if the resource is in memcached' do
          @client.expects(:get).with("api-cache:twitter:URIHASH").returns(true)
          assert_equal true, @memcached.response_body_exists?
        end

        should 'return false if the resource is not in memcached' do
          @client.expects(:get).with("api-cache:twitter:URIHASH").returns(nil)
          assert_equal false, @memcached.response_body_exists?
        end
      end

      context '#get_response_body' do
        should "retrieve the response from the cache" do
          @client.expects(:get).with("api-cache:twitter:URIHASH").returns("RESPONSE_BODY")
          assert_equal "RESPONSE_BODY", @memcached.get_response_body
        end
      end

      context '#store_response_body' do
        should "store data in memcached and set an expiration time" do
          @client.expects(:set).with("api-cache:twitter:URIHASH", "RESPONSE_BODY", 10).returns(true)
          @memcached.store_response_body("RESPONSE_BODY", 10)
        end
      end


      context '#backup_exists?' do
        should 'return true if the resource is in the memcached backup' do
          @client.expects(:get).with("api-cache:backup:twitter:URIHASH").returns(true)
          assert @memcached.backup_exists?
        end

        should 'return false if the resource is not in the memcached backup' do
          @client.expects(:get).with("api-cache:backup:twitter:URIHASH").returns(nil)
          assert_equal false, @memcached.backup_exists?
        end

        should 'return false if the backup does not exist' do
          @client.expects(:get).with("api-cache:backup:twitter:URIHASH").returns(nil)
          assert_equal false, @memcached.backup_exists?
        end
      end

      context '#get_backup' do
        should 'retrieve the response body from the backup' do
          @client.expects(:get).with("api-cache:backup:twitter:URIHASH").returns("RESPONSE_BODY")
          assert_equal "RESPONSE_BODY", @memcached.get_backup
        end
      end

      context '#store_backup' do
        should 'store the response body in the backup' do
          @client.expects(:set).with("api-cache:backup:twitter:URIHASH", "RESPONSE_BODY").returns(true)
          @memcached.store_backup("RESPONSE_BODY")
        end
      end
    end
  end
end