RDig.configuration do |cfg|

  ##################################################################
  # options you really should set

  # log file location
  cfg.log_file = '/tmp/rdig.log'

  # log level, set to :debug, :info, :warn or :error
  cfg.log_level = :info
  
  # provide one or more URLs for the crawler to start from
  cfg.crawler.start_urls = [ 'http://www.example.com/' ]

  # use something like this for crawling a file system:
  # cfg.crawler.start_urls = [ 'file:///home/bob/documents/' ]
  # beware, mixing file and http crawling is not possible and might result in
  # unpredictable results.

  # limit the crawl to these hosts. The crawler will never
  # follow any links pointing to hosts other than those given here.
  # ignored for file system crawling
  cfg.crawler.include_hosts = [ 'www.example.com' ]

  # this is the path where the index will be stored
  # caution, existing contents of this directory will be deleted!
  cfg.index.path        = '/path/to/index'

  ##################################################################
  # options you might want to set, the given values are the defaults

  # set to true to get stack traces on errors
  # cfg.verbose = false
  
  # content extraction options
  cfg.content_extraction = OpenStruct.new(
  
  # HPRICOT configuration
  # this is the html parser used by default from RDig 0.3.3 upwards.
  # Hpricot by far outperforms Rubyful Soup, and is at least as flexible when
  # it comes to selection of portions of the html documents.
    :hpricot      => OpenStruct.new(
      # css selector for the element containing the page title
      :title_tag_selector => 'title', 
      # might also be a proc returning either an element or a string:
      # :title_tag_selector => lambda { |hpricot_doc| ... }
      :content_tag_selector => 'body'
      # might also be a proc returning either an element or a string:
      # :content_tag_selector => lambda { |hpricot_doc| ... }
    )
  
  # RUBYFUL SOUP
  # This is a powerful, but somewhat slow, ruby-only html parsing lib which was
  # RDig's default html parser up to version 0.3.2. To use it, comment the
  # hpricot config above, and uncomment the following:
  #
  #  :rubyful_soup => OpenStruct.new(
  #    # provide a method that returns the title of an html document
  #    # this method may either return a tag to extract the title from, 
  #    # or a ready-to-index string.
  #    :content_tag_selector => lambda { |tagsoup|
  #      tagsoup.html.body
  #    },
  #    # provide a method that selects the tag containing the page content you 
  #    # want to index. Useful to avoid indexing common elements like navigation
  #    # and page footers for every page.
  #    :title_tag_selector         => lambda { |tagsoup|
  #      tagsoup.html.head.title
  #    }
  #  )
  )

  # crawler options
  
  # Notice: for file system crawling the include/exclude_document patterns are 
  # applied to the full path of _files_ only (like /home/bob/test.pdf), 
  # for http to full URIs (like http://example.com/index.html).
  
  # nil (include all documents) or an array of Regexps 
  # matching the URLs you want to index.
  # cfg.crawler.include_documents = nil

  # nil (no documents excluded) or an array of Regexps 
  # matching URLs not to index.
  # this filter is used after the one above, so you only need
  # to exclude documents here that aren't wanted but would be 
  # included by the inclusion patterns.
  # cfg.crawler.exclude_documents = nil
 
  # number of document fetching threads to use. Should be raised only if 
  # your CPU has idle time when indexing.
  # cfg.crawler.num_threads = 2
  # suggested setting for file system crawling:
  # cfg.crawler.num_threads = 1

  # maximum number of http redirections to follow
  # cfg.crawler.max_redirects = 5

  # number of seconds to wait with an empty url queue before 
  # finishing the crawl. Set to a higher number when experiencing incomplete
  # crawls on slow sites. Don't set to 0, even when crawling a local fs.
  # cfg.crawler.wait_before_leave = 10

  # limit the crawling depth. Default: nil (unlimited)
  # Set to 0 to only index the start_urls.
  # cfg.crawler.max_depth = nil

  # indexer options

  # create a new index on each run. Will append to the index if false. Use when
  # building a single index from multiple runs, e.g. one across a website and the
  # other a tree in a local file system
  # cfg.index.create = true

  # rewrite document uris before indexing them. This is useful if you're
  # indexing on disk, but the documents should be accessible via http, e.g. from 
  # a web based search application. By default, no rewriting takes place.
  # example:
  # cfg.index.rewrite_uri = lambda { |uri| 
  #   uri.path.gsub!(/^\/base\//, '/virtual_dir/')
  #   uri.scheme = 'http'
  #   uri.host = 'www.mydomain.com'
  # }
  
end
