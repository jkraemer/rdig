module RDig
  
  #
  # Document base class
  #
  class Document
    
    attr_reader :uri
    attr_reader :content
    attr_reader :content_type
    
    def self.create(url)
      return case url
        when /^https?:\/\//i
          HttpDocument.new(:uri => url)
        when /^file:\/\//i
          FileDocument.new(:uri => url)
      end
    end

    # url: url of this document, may be relative to the referring doc or host.
    # referrer: uri of the document we retrieved this link from
    def initialize(args)
      RDig.logger.debug "initialize: #{args.inspect}"
      begin
        @uri = URI.parse(args[:uri])
      rescue URI::InvalidURIError
        raise "Cannot create document using invalid URL: #{args[:uri]}"
      end
    end

    def title; @content[:title] end
    def body; @content[:content] end
    def links; @content[:links] end
    
    def needs_indexing?
      has_content? && (title || body)
    end

    def has_content?
      !self.content.nil?
    end

    def to_s
      "#{self.class.name}, uri=#{uri}, title=#{has_content? ? title : 'not loaded yet'}"
    end

  end

  
  #
  # Document in a File system
  #
  class FileDocument < Document
    def initialize(args={})
      super(args)
    end

    def create_child(uri)
      FileDocument.new(:uri => uri)
    end

    def self.find_files(path)
      links = []
      pattern = /.+\.(#{File::FILE_EXTENSION_MIME_TYPES.keys.join('|')})$/i
      Dir.glob(File.expand_path(File.join(path, '*'))) do |filename|
        RDig.logger.debug "checking file #{filename}"
        # Skip files not matching known mime types
        links << "file://#{filename}" if File.directory?(filename) || filename =~ pattern
      end
      links
    end

    def file?
      File.file? @uri.path
    end

    def fetch
      if File.directory? @uri.path
        # directories are treated like a link collection
        @content = { :links => self.class.find_files(@uri.path) }
      else
        # process this file's contents
        open(@uri.path) do |file|
          @content = ContentExtractors.process(file.read, file.content_type)
          @content[:links] = nil if @content # don't follow links inside files
        end
      end
      @content ||= {}
    end

  end
  
  
  #
  # Remote Document to be retrieved by HTTP
  #
  class HttpDocument < Document

    # counts how far this document is away from one of the start urls. Used to limit crawling by depth.
    attr_reader :depth         
    attr_reader :referring_uri
    attr_reader :status
    attr_reader :etag

    def create_child(uri)
      HttpDocument.new(:uri => uri, :referrer => self.uri, :depth => self.depth+1) unless uri =~ /^file:\/\//i 
    end
    
    # url: url of this document, may be relative to the referring doc or host.
    # referrer: uri of the document we retrieved this link from
    def initialize(args={})
      super(args)
      @referring_uri = args[:referrer]
      @depth = args[:depth] || 0
    end

    def fetch
      RDig.logger.debug "fetching #{@uri.to_s}"
      open(@uri.to_s, RDig::open_uri_http_options) do |doc|
        if @uri.to_s != doc.base_uri.to_s
          @status = :redirect
          @content = doc.base_uri
        else
          case doc.status.first.to_i
          when 200
            @etag = doc.meta['etag']
            @content = ContentExtractors.process(doc.read, doc.content_type)
            @status = :success
          when 404
            RDig.logger.info "got 404 for #{@uri}"
          else
            RDig.logger.info "don't know what to do with response: #{doc.status.join(' : ')}"
          end
        end
      end
    rescue
      RDig.logger.warn "error fetching #{@uri.to_s}: #{$!}"
    ensure
      @content ||= {}
    end

  end
end
