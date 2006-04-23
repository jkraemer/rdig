require 'test_helper'
class WordContentExtractorTest < Test::Unit::TestCase
  include TestHelper

  def setup
    @ce = ContentExtractors::WordContentExtractor.new(RDig.configuration.content_extraction)
  end

  def test_can_do
    assert !@ce.can_do('application/pdf')
    assert @ce.can_do('application/msword')
  end
  def test_simple_with_ctype
    result = ContentExtractors.process(word_doc('simple'), 'application/msword')
    check_content(result)
  end
  
  def test_simple
    result = @ce.process(word_doc('simple'))
    check_content(result)
  end

  private
  def check_content(result)
    assert_not_nil result
    assert_equal [], result[:links]
    assert_not_nil result[:title]
    assert_equal 'Untitled', result[:title]
    assert_not_nil result[:content]
    assert_equal 'Test content for Word content extraction. Another paragraph.', result[:content]
  end
  
end

