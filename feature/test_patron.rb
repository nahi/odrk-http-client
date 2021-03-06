# -*- encoding: utf-8 -*-
require 'patron'
require File.expand_path('./test_setting', File.dirname(__FILE__))


class TestPatron < OdrkHTTPClientTestCase
  def setup
    super
    url = URI.parse($url)
    @client = Patron::Session.new
    @client.base_url = (url + "/").to_s
    @url = url.path.sub(/^\//, '')
  end

  def test_ssl
    setup_sslserver
    ssl_url = "https://localhost:#{$ssl_port}/"
    client = Patron::Session.new
    client.base_url = (URI.parse(ssl_url) + "/").to_s
    assert_raise(Patron::Error) do
      client.get('hello')
    end
  end

  def test_ssl_ca
    setup_sslserver
    ssl_url = "https://localhost:#{$ssl_port}/"
    client = Patron::Session.new
    client.base_url = (URI.parse(ssl_url) + "/").to_s
    ca_file = File.expand_path('./fixture/ca_all.pem', File.dirname(__FILE__))
    # !! cannot configure CAfile
    assert_equal('hello ssl', client.get(ssl_url + 'hello').body)
  end

  def test_ssl_hostname
    setup_sslserver
    ssl_url = "https://127.0.0.1:#{$ssl_port}/"
    client = Patron::Session.new
    client.base_url = (URI.parse(ssl_url) + "/").to_s
    ca_file = File.expand_path('./fixture/ca_all.pem', File.dirname(__FILE__))
    # !! cannot configure CAfile
    assert_raise(Patron::Error) do
      client.get(ssl_url + 'hello')
    end
  end

  def test_gzip_get
    assert_equal('hello', @client.get(@url + 'compressed?enc=gzip').body)
    assert_equal('hello', @client.get(@url + 'compressed?enc=deflate').body)
  end

  def test_gzip_post
    assert_equal('hello', @client.post(@url + 'compressed', :enc => 'gzip').body)
    assert_equal('hello', @client.post(@url + 'compressed', :enc => 'deflate').body)
  end

  def test_put
    assert_equal("put", @client.put(@url + 'servlet', '').body)
    res = @client.put(@url + 'servlet', '1=2&3=4')
    # !! case sensitive
    assert_equal('1=2&3=4', res.headers["X-Query"])
    # bytesize
    res = @client.put(@url + 'servlet', 'txt=%E3%81%82%E3%81%84%E3%81%86%E3%81%88%E3%81%8A')
    assert_equal('txt=%E3%81%82%E3%81%84%E3%81%86%E3%81%88%E3%81%8A', res.headers["X-Query"])
    assert_equal('15', res.headers["X-Size"])
  end

  def test_delete
    assert_equal("delete", @client.delete(@url + 'servlet').body)
  end

  def test_cookies
    @client.handle_cookies
    res = @client.get(@url + 'cookies', 'Cookie' => 'foo=0; bar=1 ')
    assert_equal(2, res.headers['Set-Cookie'].size)
    res.headers['Set-Cookie'].find { |c| /foo=(\d)/ =~ c }
    assert_equal('1', $1)
    res.headers['Set-Cookie'].find { |c| /bar=(\d)/ =~ c }
    assert_equal('2', $1)
    5.times do
      res = @client.get(@url + 'cookies')
    end
    assert_equal(2, res.headers['Set-Cookie'].size)
    res.headers['Set-Cookie'].find { |c| /foo=(\d)/ =~ c }
    assert_equal('6', $1)
    res.headers['Set-Cookie'].find { |c| /bar=(\d)/ =~ c }
    assert_equal('7', $1)
  end

  def test_post_multipart
    res = @client.post_multipart(@url + 'servlet', {}, {:upload => __FILE__})
    assert_match(/FIND_TAG_IN_THIS_FILE/, res.body)
  end

  def test_basic_auth
    @client.username = 'admin'
    @client.password = 'admin'
    @client.auth_type = :basic
    assert_equal('basic_auth OK', @client.get(@url + 'basic_auth').body)
  end

  def test_digest_auth
    @client.username = 'admin'
    @client.password = 'admin'
    @client.auth_type = :digest
    assert_equal('digest_auth OK', @client.get(@url + 'digest_auth').body)
    assert_equal('digest_sess_auth OK', @client.get(@url + 'digest_sess_auth').body)
  end

  def test_redirect
    assert_equal('hello', @client.get(@url + 'redirect3').body)
  end

  def test_redirect_loop_detection
    @client.max_redirects = 10
    assert_raise(Patron::TooManyRedirects) do
      @client.get(@url + 'redirect_self').body
    end
  end

  def _test_keepalive
    server = HTTPServer::KeepAliveServer.new($host)
    begin
      5.times do
        assert_equal('12345', @client.get(server.url).body)
      end
    ensure
      server.close
    end
    # chunked
    server = HTTPServer::KeepAliveServer.new($host)
    begin
      5.times do
        assert_equal('abcdefghijklmnopqrstuvwxyz1234567890abcdef', @client.get(server.url + 'chunked').body)
      end
    ensure
      server.close
    end
  end

  def test_streaming_upload
    file = Tempfile.new(__FILE__)
    file << "*" * 4096 * 100
    file.close
    file.open
    res = @client.request(:post, @url + 'chunked', {}, :file => file.path)
    # !! case sensitive
    assert(res.headers['X-Count'].to_i >= 26)
    if filename = res.headers['X-Tmpfilename']
      File.unlink(filename)
    end
  end

  def test_streaming_download
    file = Tempfile.new('download')
    begin
      @client.get_file(@url + 'largebody', file.path)
      assert_equal(10000000, File.read(file.path).size)
    ensure
      file.unlink
    end
  end

  if RUBY_VERSION > "1.9"
    def test_charset
      body = @client.get(@url + 'charset').body
      assert_equal(Encoding::EUC_JP, body.encoding)
      assert_equal('あいうえお'.encode(Encoding::EUC_JP), body)
    end
  end
end
