require 'test_helper'
class PdfContentExtractorTest < Test::Unit::TestCase
  include TestHelper

  def setup
    @ce = ContentExtractors::PdfContentExtractor.new(RDig.configuration.content_extraction)
  end

  def test_can_do
    assert @ce.can_do('application/pdf')
    assert !@ce.can_do('application/msword')
  end
  def test_simple_with_ctype
    result = ContentExtractors.process(pdf_doc('simple'), 'application/pdf')
    check_content(result)
  end
  
  def test_simple
    result = @ce.process(pdf_doc('simple'))
    check_content(result)
  end

  private
  def check_content(result)
    assert_not_nil result
    assert_equal 'PDF Test', result[:title]
    assert_nil result[:links]
    assert_not_nil result[:content]
    assert_equal 'This is for testing PDF extraction. Some Ümläuts and a €uro. Another Paragraph.', result[:content]
  end
  
end

