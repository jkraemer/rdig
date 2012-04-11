module RDig
  class Crawler

    def initialize(config = RDig.config, logger = RDig.logger)
      @documents = Queue.new
      @logger = logger
      @config = config
      @indexed_documents = 0
    end

    def run
      @indexer = Index::Indexer.new(@config.index)
      crawl
    ensure
      @indexer.close if @indexer
    end

    def crawl
      raise 'no start urls given!' if @config.crawler.start_urls.empty?
      # check whether we are indexing on-disk or via http
      url_type = @config.crawler.start_urls.first =~ /^file:\/\// ? :file : :http
      chain_config = RDig.filter_chain[url_type]

      # the etag filter operates on the fetched document, thats why we cannot put it into the filter chain right now.
      @etag_filter = ETagFilter.new
      filterchain = UrlFilters::FilterChain.new(chain_config)
      @config.crawler.start_urls.each { |url| add_url(url, filterchain) }

      num_threads = @config.crawler.num_threads
      group = ThreadsWait.new
      num_threads.times { |i|
        group.join_nowait Thread.new("fetcher #{i}") {
          filterchain = UrlFilters::FilterChain.new(chain_config)
          @logger.info "thread #{i} running..."
          while (doc = @documents.pop) != :exit
            process_document doc, filterchain
          end
          @logger.info "thread #{i} is done."
        }
      }

      # check for an empty queue every now and then 
      sleep_interval = @config.crawler.wait_before_leave
      begin 
        sleep sleep_interval
      end until @documents.empty?
      # nothing to do any more, tell the threads to exit
      num_threads.times { @documents << :exit }

      @logger.info "waiting for threads to finish..."
      group.all_waits
      @logger.info "indexed #{@indexer.indexed_documents} documents"
    end

    def process_document(doc, filterchain)
      @logger.info "processing document #{doc.uri}"
      doc.fetch
      case doc.status
      when :success
        if @etag_filter.apply(doc) 
          # add links from this document to the queue
          doc.content[:links].each { |url| 
            add_url(url, filterchain, doc) 
          } unless doc.content[:links].nil?
          add_to_index doc
        end
      when :redirect
        @logger.debug "redirect to #{doc.content}"
        add_url(doc.content, filterchain, doc)
      else
        @logger.error "unknown doc status #{doc.status}: #{doc}"
      end
    rescue
      @logger.error "error processing document #{doc.uri.to_s}: #{$!}"
      @logger.info "Trace: #{$!.backtrace.join("\n")}"
    end

    def add_to_index(doc)
      if doc.needs_indexing?
        @indexer << doc
      end
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

      if doc = filterchain.apply(doc)
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
      return document unless (document.respond_to?(:etag) && document.etag && !document.etag.empty?)
      synchronize do
        @etags.add?(document.etag) ? document : nil 
      end
    end
  end

end
