# -*- encoding: utf-8 -*-
require 'test/unit'
require 'wrest'
require File.expand_path('./test_setting', File.dirname(__FILE__))
require File.expand_path('./httpserver', File.dirname(__FILE__))


class TestWrest < Test::Unit::TestCase
  def setup
    @server = HTTPServer.new($host, $port)
    Wrest.use_native! # use net/http. Cannot use Patron because it's blocking.
    @url = $url
  end

  def teardown
    @server.shutdown
  end

  def test_gzip_get
    assert_equal('hello', (@url + 'compressed?enc=gzip').to_uri.get.body)
    assert_equal('hello', (@url + 'compressed?enc=deflate').to_uri.get.body)
  end

  def test_gzip_post
    assert_equal('hello', (@url + 'compressed').to_uri.post('enc=gzip').body)
    assert_equal('hello', (@url + 'compressed').to_uri.post('enc=deflate').body)
  end

  def test_put
    assert_equal("put", (@url + 'servlet').to_uri.put.body)
    res = (@url + 'servlet').to_uri.put('1=2&3=4')
    assert_equal('1=2&3=4', res.headers["x-query"])
    # bytesize
    res = (@url + 'servlet').to_uri.put('txt=%E3%81%82%E3%81%84%E3%81%86%E3%81%88%E3%81%8A')
    assert_equal('txt=%E3%81%82%E3%81%84%E3%81%86%E3%81%88%E3%81%8A', res.headers["x-query"])
    assert_equal('15', res.headers["x-size"])
  end

  def test_delete
    assert_equal("delete", (@url + 'servlet').to_uri.delete.body)
  end

  def test_cookies
    flunk('Cookie is not supported')
  end

  def test_post_multipart
    require 'wrest/multipart'
    File.open(__FILE__) do |file|
      res = (@url + 'servlet').to_uri.post_multipart(:upload => Wrest::Native::PostMultipart::UploadIO.new(file, 'text/plain'))
      assert_match(/FIND_TAG_IN_THIS_FILE/, res.body)
    end
  end

  def test_basic_auth
    assert_equal('basic_auth OK', (@url + 'basic_auth').to_uri(:username => 'admin', :password => 'admin').get.body)
  end

  def test_digest_auth
    flunk('digest auth not supported')
  end

  def test_redirect
    assert_equal('hello', (@url + 'redirect3').to_uri.get.body)
  end

  def test_redirect_loop_detection
    assert_raise(Wrest::Exceptions::AutoRedirectLimitExceeded) do
      (@url + 'redirect_self').to_uri(:follow_redirects_limit => 10).get
    end
  end
end
