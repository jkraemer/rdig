# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rdig}
  s.version = "0.3.8"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Jens Kraemer"]
  s.date = %q{2009-04-26}
  s.description = %q{Website crawler and fulltext indexer.}
  s.email = %q{jk@jkraemer.net}
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README"]
  s.files = %w(
    CHANGES
    History.txt
    install.rb
    LICENSE
    Manifest.txt
    rakefile
    README
    bin/rdig
    doc/examples/config.rb
    lib/rdig/content_extractors/doc.rb
    lib/rdig/content_extractors/hpricot.rb
    lib/rdig/content_extractors/pdf.rb
    lib/rdig/content_extractors.rb
    lib/rdig/crawler.rb
    lib/rdig/documents.rb
    lib/rdig/file.rb
    lib/rdig/highlight.rb
    lib/rdig/index.rb
    lib/rdig/search.rb
    lib/rdig/url_filters.rb
    lib/rdig.rb
  )
  s.has_rdoc = true
  s.homepage = %q{ http://github.com/jkraemer/rdig/ }
  s.rdoc_options = ["--main", "README"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{rdig}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{Crawler and content extractor for building a full text index of a website's contents. Uses Ferret for indexing.}
  s.test_files = %w(
    test/fixtures/html/custom_tag_selectors.html
    test/fixtures/html/entities.html
    test/fixtures/html/frameset.html
    test/fixtures/html/imagemap.html
    test/fixtures/html/simple.html
    test/fixtures/pdf/simple.pdf
    test/fixtures/word/simple.doc
    test/test_helper.rb
    test/unit/crawler_fs_test.rb
    test/unit/etag_filter_test.rb
    test/unit/file_document_test.rb
    test/unit/hpricot_content_extractor_test.rb
    test/unit/http_document_test.rb
    test/unit/pdf_content_extractor_test.rb
    test/unit/rdig_test.rb
    test/unit/searcher_test.rb
    test/unit/url_filters_test.rb
    test/unit/word_content_extractor_test.rb
  )

  s.add_dependency(%q<ferret>, [">= 0.11.6"])
  s.add_dependency(%q<hpricot>, [">= 0.6"])
  s.add_dependency(%q<htmlentities>, [">= 4.0.0"])
end
