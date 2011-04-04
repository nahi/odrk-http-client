# -*- encoding: utf-8 -*-
require 'test/unit'
require 'excon'
require File.expand_path('./test_setting', File.dirname(__FILE__))
require File.expand_path('./httpserver', File.dirname(__FILE__))


class TestExcon < Test::Unit::TestCase
  def setup
    @server = HTTPServer.new($host, $port)
    @client = Excon
    @url = $url
  end

  def teardown
    @server.shutdown
  end

  def test_gzip_get
    assert_equal('hello', @client.get(@url + 'compressed?enc=gzip').body)
    assert_equal('hello', @client.get(@url + 'compressed?enc=deflate').body)
    @client.transparent_gzip_decompression = false
  end

  def test_gzip_post
    assert_equal('hello', @client.post(@url + 'compressed', :enc => 'gzip').body)
    assert_equal('hello', @client.post(@url + 'compressed', :enc => 'deflate').body)
  end

  def test_put
    assert_equal("put", @client.put(@url + 'servlet').body)
    res = @client.put(@url + 'servlet', :body => '1=2&3=4')
    # !! res.headers is a Hash, case sensitive
    assert_equal('1=2&3=4', res.headers["X-Query"])
    # bytesize
    res = @client.put(@url + 'servlet', :body => 'txt=%E3%81%82%E3%81%84%E3%81%86%E3%81%88%E3%81%8A')
    assert_equal('txt=%E3%81%82%E3%81%84%E3%81%86%E3%81%88%E3%81%8A', res.headers["X-Query"])
    assert_equal('15', res.headers["X-Size"])
  end

  def test_delete
    assert_equal("delete", @client.delete(@url + 'servlet').body)
  end

  def test_cookies
    raise 'Cookie is not supported'
  end

  def test_post_multipart
    File.open(__FILE__) do |file|
      res = @client.post(@url + 'servlet', :upload => file)
      assert_match(/FIND_TAG_IN_THIS_FILE/, res.body)
    end
  end
end
