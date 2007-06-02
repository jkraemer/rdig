require 'test_helper'
class HttpDocumentTest < Test::Unit::TestCase
  include TestHelper

  def setup
    @fixture_path = File.join(File.expand_path(File.dirname(__FILE__)), '../fixtures/')
  end

  def test_initialize
    d = Document.create 'http://1stlineleewes.com'
    assert_equal '1stlineleewes.com', d.uri.host
    assert_equal '', d.uri.path
  end

end


