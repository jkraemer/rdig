RDig.configuration do |cfg|

  ##################################################################
  # options you should really set
  
  # provide one or more URLs for the crawler to start from
  cfg.crawler.start_urls = [ 'http://www.example.com/' ]

  # limit the crawl to these hosts. The crawler will never
  # follow any links pointing to hosts other than those given here.
  cfg.crawler.include_hosts = [ 'www.example.com' ]

  # this is the path where the index will be stored
  # caution, existing contents of this directory will be deleted!
  cfg.ferret.path        = '/path/to/index'

  ##################################################################
  # options you might want to set, the given values are the defaults

  # set to true to get stack traces on errors
  # cfg.verbose = false
  
  # content extraction options
  
  # provide a method that selects the tag containing the title of a document
  # cfg.content_extraction.html.title_tag_selector = lambda { |tagsoup| tagsoup.html.head.title }
  
  # provide a method that selects the tag containing the page content you 
  # want to index. Useful to avoid indexing common elements like navigation
  # and page footers for every page.
  # cfg.content_extraction.html.content_tag_selector = lambda { |tagsoup| tagsoup.html.body }
  
  # crawler options
  
  # nil (index all documents) or an array of Regexps 
  # matching URLs you want to index.
  # cfg.crawler.include_documents = nil

  # nil (no documents excluded) or an array of Regexps 
  # matching URLs not to index.
  # this filter is used after the one above, so you only need
  # to exclude documents here that aren't wanted but would be 
  # included by the inclusion patterns.
  # cfg.crawler.exclude_documents = nil
 
  # number of http fetching threads to use
  # cfg.crawler.num_threads = 2

  # maximum number of http redirections to follow
  # cfg.crawler.max_redirects = 5

  # number of seconds to wait with an empty url queue before 
  # finishing the crawl. Set to a higher number for slow sites
  # cfg.crawler.wait_before_leave = 10
  
end
