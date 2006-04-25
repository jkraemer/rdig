module RDig
  
  
  class Crawler
    
    def initialize
      @documents = Queue.new
      @etag_filter = ETagFilter.new
    end

    def run
      raise 'no start urls given!' if RDig.config.crawler.start_urls.empty?
      @indexer = Index::Indexer.new(RDig.config.ferret)
      
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

      # dilemma: suppose we have 1 start url and two threads t1 and t2:
      # t1 pops the start url from the queue which now is empty
      # as the queue is empty now, t2 blocks until t1 adds the links 
      # retrieved from his document.
      #
      # But we need the 'queue empty' condition as a sign for us to stop
      # waiting for new entries, too.
      
      # check every now and then for an empty queue
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
      puts "fetching #{doc.uri.to_s}" if RDig::config.verbose
      doc.fetch
      # add links from this document to the queue
      doc.content[:links].each { |url| 
        add_url(url, filterchain, doc) 
      } unless doc.content[:links].nil?

      return unless @etag_filter.apply(doc)
      @indexer << doc if doc.needs_indexing?
    rescue
      puts "error processing document #{doc.uri.to_s}: #{$!}"
      puts "Trace: #{$!.backtrace.join("\n")}" if RDig::config.verbose
    end

    
    # pipes a new document pointing to url through the filter chain, 
    # if it survives that, it gets added to the documents queue for further
    # processing
    def add_url(url, filterchain, referring_document = nil)
      return if url.nil? || url.empty?
      if referring_document and referring_document.uri.scheme =~ /^https?/i
        doc = Document.create(url, referring_document.uri)
      else
        doc = Document.create(url)
      end

      doc = filterchain.apply(doc)
        
      if doc
        @documents << doc
        puts "added url #{url}" if RDig::config.verbose
      end
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
