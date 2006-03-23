module RDig
    
  class Crawler
    
    def initialize
      @documents = Queue.new
    end


    def run
      @indexer = Indexer.new(RDig.config.ferret)
      RDig.config.crawler.start_urls.each { |url| add_url(url) }
      
      num_threads = RDig.config.crawler.num_threads
      group = ThreadsWait.new
      num_threads.times { |i|
        group.join_nowait Thread.new("fetcher #{i}") {
          filterchain = UrlFilters::FilterChain.new(RDig.filter_chain)
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
      doc.fetch
      case doc.status
      when :success
        if doc.content
          if doc.content[:links]
            doc.content[:links].each { |url| add_url(url, filterchain, doc) }
          end
          @indexer << doc
          #else
          #puts "success but no content: #{doc.uri.to_s}"
        end
      when :redirect
        # links contains the url we were redirected to
        doc.content[:links].each { |url| add_url(url, filterchain, doc) }
      end
    rescue
      puts "error processing document #{doc.uri.to_s}: #{$!}"
    end

    
    # pipes a new document pointing to url through the filter chain, 
    # if it survives that, it gets added to the documents queue for further
    # processing
    def add_url(url, filterchain = nil, referring_document = nil)
      return if url.nil? || url.empty?
      if referring_document
        doc = Document.new(url, referring_document.uri)
        # keep redirect count
        if referring_document.status == :redirect
          doc.redirections = referring_document.redirections + 1
        end
      else
        doc = Document.new(url)
      end

      doc = filterchain.apply(doc) if filterchain
        
      if doc
        puts "added url #{url}"
        #else
        #puts "skipping url #{url}"
      end
      @documents << doc if doc
    end
    
  end

  
  class Document
    include HttpClient

    attr_reader :content
    attr_reader :content_type
    attr_reader :uri
    attr_reader :referring_uri
    attr_reader :status
    attr_accessor :redirections
    
    # url: url of this document, may be relative to the referring doc or host.
    # referrer: uri of the document we retrieved this link from
    def initialize(url, referrer = nil)
      @redirections = 0
      begin
        @uri = URI.parse(url)
      rescue URI::InvalidURIError
        raise "Cannot create document using invalid URL: #{url}"
      end
      @referring_uri = referrer
    end

    def has_content?
      !self.content.nil?
    end

    def title; @content[:title] end
    def body; @content[:content] end
    def url; @uri.to_s end

    def fetch
      puts "fetching #{@uri.to_s}"
      response = do_get(@uri)
      case response
      when Net::HTTPSuccess
        @content_type = response['content-type']
        @raw_body = response.body
        # todo externalize this (another chain ?)
        @content = ContentExtractors.process(@raw_body, @content_type)
        @status = :success
      when Net::HTTPRedirection
        @status = :redirect
        @content = { :links => [ response['location'] ] }
      else
        puts "dunno what to do with response: #{response}"
      end
       
    end

  end

end
