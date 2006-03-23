#
# sample RDig configuration file, edit to taste
#

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
  
  # nil (index all documents) or a list of Regexps 
  # matching URLs you want to index.
  # cfg.crawler.include_documents = nil

  # nil (no documents excluded) or a list of Regexps 
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
