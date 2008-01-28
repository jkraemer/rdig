module RDig
  
  
  class Crawler
    
    def initialize
      @documents = Queue.new
      @etag_filter = ETagFilter.new
      @logger = RDig.logger
    end

    def run
      raise 'no start urls given!' if RDig.config.crawler.start_urls.empty?
      @indexer = Index::Indexer.new(RDig.config.index)
      
      # check whether we are indexing on-disk or via http
      url_type = RDig.config.crawler.start_urls.first =~ /^file:\/\// ? :file : :http
      chain_config = RDig.filter_chain[url_type]
      
      filterchain = UrlFilters::FilterChain.new(chain_config)
      RDig.config.crawler.start_urls.each { |url| add_url(url, filterchain) }

      num_threads = RDig.config.crawler.num_threads
      group = ThreadsWait.new
      num_threads.times { |i|
        group.join_nowait Thread.new("fetcher #{i}") {
          filterchain = UrlFilters::FilterChain.new(chain_config)
          while (doc = @documents.pop) != :exit
            process_document doc, filterchain
          end
        }
      }

      # check for an empty queue every now and then 
      sleep_interval = RDig.config.crawler.wait_before_leave
      begin 
        sleep sleep_interval
      end until @documents.empty?
      # nothing to do any more, tell the threads to exit
      num_threads.times { @documents << :exit }

      puts "waiting for threads to finish..."
      group.all_waits
    ensure
      @indexer.close if @indexer
    end

    def process_document(doc, filterchain)
      @logger.debug "processing document #{doc}"
      doc.fetch
      # add links from this document to the queue
      doc.content[:links].each { |url| 
        add_url(url, filterchain, doc) 
      } unless doc.content[:links].nil?

      return unless @etag_filter.apply(doc)
      @indexer << doc if doc.needs_indexing?
    rescue
      @logger.error "error processing document #{doc.uri.to_s}: #{$!}"
      @logger.debug "Trace: #{$!.backtrace.join("\n")}"
    end

    
    # pipes a new document pointing to url through the filter chain, 
    # if it survives that, it gets added to the documents queue for further
    # processing
    def add_url(url, filterchain, referring_document = nil)
      return if url.nil? || url.empty?

      @logger.debug "add_url #{url}"
      doc = if referring_document
        referring_document.create_child(url)
      else
        Document.create(url)
      end

      doc = filterchain.apply(doc)
        
      if doc
        @documents << doc
        @logger.debug "url #{url} survived filterchain"
      end
    rescue
      nil
    end
    
  end

  
  # checks fetched documents' E-Tag headers against the list of E-Tags
  # of the documents already indexed.
  # This is supposed to help against double-indexing documents which can 
  # be reached via different URLs (think http://host.com/ and 
  # http://host.com/index.html )
  # Documents without ETag are allowed to pass through
  class ETagFilter
    include MonitorMixin

    def initialize
      @etags = Set.new
      super
    end

    def apply(document)
      return document unless (document.respond_to?(:etag) && document.etag)
      synchronize do
        @etags.add?(document.etag) ? document : nil 
      end
    end
  end

end
