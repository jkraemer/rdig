require 'test_helper'
class UrlFilterTest < Test::Unit::TestCase
  include TestHelper, RDig

  def setup
  end

  # test a chain configured with direct parameters
  def test_filterchain
    cfg = [
      { UrlFilters::UrlInclusionFilter => /.+html$/ },
      { :hostname_filter => 'test.host' }
    ]
    chain = UrlFilters::FilterChain.new(cfg)

    assert_nil chain.apply(Document.create("http://test.host/affe.htm"))
    assert_not_nil chain.apply(Document.create("http://test.host/affe.html"))
    assert_nil chain.apply(Document.create("http://test.host.com/affe.html"))
  end

  # test default chain config
  def test_default_filterchain
    chain = UrlFilters::FilterChain.new(RDig.filter_chain)
    assert_nil chain.apply(Document.create("http://www.example.com/affe.htm"))
    assert_not_nil chain.apply(Document.create("http://localhost:3000/affe.html"))
    assert_nil chain.apply(Document.create("http://localhost.com/affe.html"))
  end
  
  # check lookup of chain parameters from config
  def test_filterchain_config
    RDig.configuration do |conf|
      conf.crawler.include_patterns = /.+html$/
      conf.crawler.include_hosts = 'test.host'
    end
    cfg = [
      { UrlFilters::UrlInclusionFilter => :include_patterns },
      { :hostname_filter => :include_hosts }
    ]
    chain = UrlFilters::FilterChain.new(cfg)

    assert_nil chain.apply(Document.create("http://test.host/affe.htm"))
    assert_not_nil chain.apply(Document.create("http://test.host/affe.html"))
    assert_nil chain.apply(Document.create("http://test.host.com/affe.html"))
  end
  
  def test_urlpattern_filter
    f = UrlFilters::UrlInclusionFilter.new(/.*\.html$/)
    assert_nil f.apply(Document.create("http://test.host/affe.htm"))
    assert_not_nil f.apply(Document.create("http://test.host/affe.html"))
    f = UrlFilters::UrlExclusionFilter.new([ /.*\.html$/, /.*\.aspx/ ])
    assert_not_nil f.apply(Document.create("http://test.host/affe.htm"))
    assert_nil f.apply(Document.create("http://test.host/affe.html"))
    assert_nil f.apply(Document.create("http://test.host/affe.aspx"))
    f = UrlFilters::UrlExclusionFilter.new([ /http:\/\/[^\/]+\/dir1/ ])
    assert_nil f.apply(Document.create("http://test.host/dir1/affe.aspx"))
    assert_not_nil f.apply(Document.create("http://test.host/dir2/dir1/affe.htm"))
    assert_not_nil f.apply(Document.create("http://test.host/affe.htm"))
    assert_not_nil f.apply(Document.create("http://test.host/dir2/affe.htm"))
    f = UrlFilters::UrlExclusionFilter.new([ /\/dir1/ ])
    assert_nil f.apply(Document.create("http://test.host/dir1/affe.aspx"))
    assert_nil f.apply(Document.create("http://test.host/dir2/dir1/affe.htm"))
    assert_not_nil f.apply(Document.create("http://test.host/affe.htm"))
    assert_not_nil f.apply(Document.create("http://test.host/dir2/affe.htm"))
  end

  def test_hostname_filter
    include_hosts = [ 'test.host', 'localhost' ]
    assert_nil UrlFilters.hostname_filter(Document.create('http://google.com/'), include_hosts)
    assert_not_nil UrlFilters.hostname_filter(Document.create('http://test.host/file.html'), include_hosts)
    assert_not_nil UrlFilters.hostname_filter(Document.create('http://localhost/file.html'), include_hosts)
  end

  def test_fix_relative_uri
    doc = Document.create('http://test.host/dir/file.html')
    assert_equal('http://test.host/dir/another.html',
                  UrlFilters.fix_relative_uri(Document.create('another.html', doc.uri)).uri.to_s)
    assert_equal('http://test.host/dir/../another.html',
                  UrlFilters.fix_relative_uri(Document.create('../another.html', doc.uri)).uri.to_s)
    assert_equal('http://test.host/dir/another.html',
                  UrlFilters.fix_relative_uri(Document.create('/dir/another.html', doc.uri)).uri.to_s)
    assert_equal('http://test.host/dir/another.html',
                  UrlFilters.fix_relative_uri(Document.create('http://test.host/dir/another.html', doc.uri)).uri.to_s)
    assert_equal('HTTP://test.host/dir/another.html',
                  UrlFilters.fix_relative_uri(Document.create('HTTP://test.host/dir/another.html', doc.uri)).uri.to_s)
    doc = Document.create('https://test.host/dir/')
    assert_equal('https://test.host/dir/another.html',
                  UrlFilters.fix_relative_uri(Document.create('another.html', doc.uri)).uri.to_s)
    doc = Document.create('https://test.host/')
    assert_equal('https://test.host/another.html',
                  UrlFilters.fix_relative_uri(Document.create('another.html', doc.uri)).uri.to_s)
    doc = Document.create('https://test.host')
    assert_equal('https://test.host/another.html',
                  UrlFilters.fix_relative_uri(Document.create('another.html', doc.uri)).uri.to_s)
  end
end

