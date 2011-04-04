# -*- encoding: utf-8 -*-
require 'test/unit'
require 'rest_client'
require File.expand_path('./test_setting', File.dirname(__FILE__))
require File.expand_path('./httpserver', File.dirname(__FILE__))


class TestRestClient < Test::Unit::TestCase
  def setup
    @server = HTTPServer.new($host, $port)
    RestClient.proxy = $proxy if $proxy
    @client = RestClient
    @url = $url
  end

  def teardown
    @server.shutdown
  end

  def test_gzip_get
    assert_equal('hello', @client.get(@url + 'compressed?enc=gzip'))
    assert_equal('hello', @client.get(@url + 'compressed?enc=deflate'))
  end

  def test_gzip_post
    assert_equal('hello', @client.post(@url + 'compressed', :enc => 'gzip'))
    assert_equal('hello', @client.post(@url + 'compressed', :enc => 'deflate'))
  end

  def test_put
    assert_equal("put", @client.put(@url + 'servlet', ''))
    res = @client.put(@url + 'servlet', '1=2&3=4')
    assert_equal('1=2&3=4', res.headers[:x_query])
    # bytesize
    res = @client.put(@url + 'servlet', 'txt=%E3%81%82%E3%81%84%E3%81%86%E3%81%88%E3%81%8A')
    assert_equal('txt=%E3%81%82%E3%81%84%E3%81%86%E3%81%88%E3%81%8A', res.headers[:x_query])
    assert_equal('15', res.headers[:x_size])
  end

  def test_delete
    assert_equal("delete", @client.delete(@url + 'servlet'))
  end

  def test_cookies
    res = @client.get(@url + 'cookies', :cookies => {:foo => '0', :bar => '1'})
    # It returns 3. It looks fail to parse expiry date. 'Expires' => 'Sun'
    assert_equal(2, res.cookies.size)
    5.times do
      res = @client.get(@url + 'cookies')
    end
    assert_equal(2, res.cookies.size)
    assert_equal('6', res.cookies.find { |c| c.name == 'foo' }.value)
    assert_equal('7', res.cookies.find { |c| c.name == 'bar' }.value)
  end

  def test_post_multipart
    File.open(__FILE__) do |file|
      res = @client.post(@url + 'servlet', :upload => file)
      assert_match(/FIND_TAG_IN_THIS_FILE/, res.body)
    end
  end

  def test_basic_auth
    resource = RestClient::Resource.new(@url + 'basic_auth', :user => 'admin', :password => 'admin')
    assert_equal('basic_auth OK', resource.get.body)
    # you can use http://user:pass@host/path style, too.
  end

  def test_digest_auth
    flunk 'digest auth is not supported'
    flunk 'digest-sess auth is not supported'
  end

  def test_redirect
    assert_equal('hello', @client.get(@url + 'redirect3').body)
  end

  def test_redirect_loop_detection
    timeout(2) do
      @client.get(@url + 'redirect_self').body
    end
  end
end
