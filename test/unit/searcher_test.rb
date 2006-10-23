require 'test_helper'
class SearcherTest < Test::Unit::TestCase
  include TestHelper

  def setup
    @fixture_path = File.expand_path(File.join(File.dirname(__FILE__), '../fixtures/'))
    index_dir = 'tmp/test-index'
    Dir.mkdir index_dir unless File.directory? index_dir
    RDig.configuration do |cfg|
      @old_crawler_cfg = cfg.crawler.clone
      cfg.crawler.start_urls = [ "file://#{@fixture_path}" ]
      cfg.crawler.num_threads = 1
      cfg.crawler.wait_before_leave = 1
      cfg.index.path = index_dir
      cfg.verbose = true
    end
    crawler = Crawler.new
    crawler.run
  end

  def teardown
    RDig.configuration do |cfg|
      cfg.crawler = @old_crawler_cfg
    end
  end

  def test_search
    result = RDig.searcher.search 'some sample text'
    assert_equal 3, result[:hitcount]
    assert_equal 3, result[:list].size
  end

end


