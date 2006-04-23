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
        raise "Cannot create document using invalid URL: #{url}"
      end
    end

    def title; @content[:title] end
    def body; @content[:content] end
    def url; @uri.to_s end

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
      # Only visit files with known extensions.
      pattern = "**/*{#{File::FILE_EXTENSION_MIME_TYPES.keys.join(',')}}"
      Dir.glob(File.join(path, pattern), File::FNM_CASEFOLD) do |filename|
        # Skip files in Darcs repositories or hidden directories.
        if File.file?(filename) and not filename =~ /.*\/(_darcs|\..+?)\/.*/
          links << "file://#{filename}"
        end
      end
      links
    end

    def fetch
      if File.directory? @uri.path
        # verzeichnis ? --> links setzen und fertich
        @content = { :links => find_files(@uri.path) }
      else
        # sonst -> datei lesen
        open(@uri.path) do |file|
          @content = ContentExtractors.process(file.read, file.content_type)
        end
      end
      @content ||= {}
    end

  end
  
  
  #
  # Remote Document to be retrieved by HTTP
  #
  class HttpDocument < Document
    include HttpClient

    attr_reader :referring_uri
    attr_reader :status
    attr_reader :etag
    attr_accessor :redirections
    
    # url: url of this document, may be relative to the referring doc or host.
    # referrer: uri of the document we retrieved this link from
    def initialize(args={})
      super(args)
      @redirections = 0
      @referring_uri = args[:referrer]
    end

    def fetch
      puts "fetching #{@uri.to_s}"
      response = do_get(@uri)
      case response
      when Net::HTTPSuccess
        @content_type = response['content-type']
        @raw_body = response.body
        @etag = response['etag']
        # todo externalize this (another chain ?)
        @content = ContentExtractors.process(@raw_body, @content_type)
        @status = :success
      when Net::HTTPRedirection
        @status = :redirect
        @content = { :links => [ response['location'] ] }
      when Net::HTTPNotFound
        puts "got 404 for #{url}"
      else
        puts "don't know what to do with response: #{response}"
      end
      @content ||= {}
    end

  end
end
