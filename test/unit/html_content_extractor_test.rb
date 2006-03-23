require 'test_helper'
class HtmlContentExtractorTest < Test::Unit::TestCase
  include TestHelper

  def setup
    @extractor = ContentExtractors::HtmlContentExtractor
    @nbsp = [160].pack('U') # non breaking space
  end

  def test_simple
    result = @extractor.process(html_doc('simple'))
    assert_not_nil result
    assert_equal 'Sample Title', result[:title]
    assert_not_nil result[:content]
    assert_not_nil result[:links]
    assert_equal 1, result[:links].size
    assert_equal 'A Link Affe Some sample text Lorem ipsum', result[:content]
    assert_equal 'http://test.host/affe.html', result[:links].first
  end

  def test_entities
    result = @extractor.process(html_doc('entities'))
    assert_equal 'Sample & Title', result[:title]
    assert_equal 'http://test.host/affe.html?b=a&c=d', result[:links].first
    assert_equal 'http://test.host/affe2.html?b=a&c=d', result[:links].last
    assert_equal "Some > Links don't#{@nbsp}break me! Affe Affe Ümläuts heiß hier ß", result[:content]
  end
  
end

