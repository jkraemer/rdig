require 'test_helper'
class FileDocumentTest < Test::Unit::TestCase
  include TestHelper

  def setup
    @fixture_path = File.join(File.expand_path(File.dirname(__FILE__)), '../fixtures/')
  end

  def test_find_files
    links = FileDocument.find_files(@fixture_path)
    assert_equal 3, links.size
    links = FileDocument.find_files("#{@fixture_path}/html")
    assert_equal 3, links.size
  end

  def test_fetch_directory
    dir = Document.create("file://#{@fixture_path}")
    dir.fetch
    assert_equal 3, dir.links.size
    dir = Document.create("file://#{@fixture_path}/pdf")
    dir.fetch
    assert_equal 1, dir.links.size
  end

  def test_fetch_content
    file = Document.create("file://#{@fixture_path}/pdf/simple.pdf")
    file.fetch
    assert file.needs_indexing?
    assert_equal 'This is for testing PDF extraction. Some Ümläuts and a €uro. Another Paragraph.', file.body
  end
  
end


