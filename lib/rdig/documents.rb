module RDig
  
  #
  # Document base class
  #
  class Document
    
    attr_reader :uri
    attr_reader :content
    attr_reader :content_type
    
    def self.create(url, referrer_uri = nil)
      # a referrer is a clear enough hint to create an HttpDocument
      if referrer_uri && referrer_uri.scheme =~ /^https?$/i
        return HttpDocument.new(:url => url, :referrer => referrer_uri)
      end
        
      case url
      when /^https?:\/\//i
        HttpDocument.new(:url => url, :referrer => referrer_uri) if referrer_uri.nil?
      when /^file:\/\//i
        # files don't have referrers - the check for nil prevents us from being
        # tricked into indexing local files by file:// links in the web site
        # we index.
        FileDocument.new(:url => url) if referrer_uri.nil?
      end
    end

    # url: url of this document, may be relative to the referring doc or host.
    # referrer: uri of the document we retrieved this link from
    def initialize(args)
      begin
        @uri = URI.parse(args[:url])
      rescue URI::InvalidURIError
        raise "Cannot create document using invalid URL: #{args[:url]}"
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

  end

  
  #
  # Document in a File system
  #
  class FileDocument < Document
    def initialize(args={})
      super(args)
    end

    def self.find_files(path)
      links = []
      Dir.glob(File.expand_path(File.join(path, '*'))) do |filename|
        # Skip files not matching known mime types
        pattern = /.+\.(#{File::FILE_EXTENSION_MIME_TYPES.keys.join('|')})$/i
        if File.directory?(filename) || filename =~ pattern
          links << "file://#{filename}"
        end
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

    attr_reader :referring_uri
    attr_reader :status
    attr_reader :etag
    
    # url: url of this document, may be relative to the referring doc or host.
    # referrer: uri of the document we retrieved this link from
    def initialize(args={})
      super(args)
      @referring_uri = args[:referrer]
    end

    def fetch
      puts "fetching #{@uri.to_s}" if RDig::config.verbose
      open(@uri.to_s) do |doc|
        case doc.status.first.to_i
        when 200
          @etag = doc.meta['etag']
          # puts "etag: #{@etag}"
          @content = ContentExtractors.process(doc.read, doc.content_type)
          @status = :success
        when 404
          puts "got 404 for #{@uri}"
        else
          puts "don't know what to do with response: #{doc.status.join(' : ')}"
        end
      end
    rescue
      puts "error fetching #{@uri.to_s}: #{$!}" if RDig::config.verbose
    ensure
      @content ||= {}
    end

  end
end
