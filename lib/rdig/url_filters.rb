module RDig
  
  module UrlFilters

    class FilterChain
      def initialize(chain_config)
        @filters = []
        chain_config.each { |filter|
          case filter
          when Hash
            filter.each_pair { |f, args|
              add(f, args)
            }
          when Array
            args = filter
            filter = args.shift
            add(filter, args)
          else
            add(filter)
          end
        }
      end

      # add a filter and it's args to the chain
      # when args is a symbol, it is treated as a configuration key
      def add(filter, args=nil)
        args = RDig.config.crawler.send(args) if args.is_a? Symbol
        case filter
        when Symbol
          if args.nil?
            @filters << lambda { |document|
              UrlFilters.send(filter, document)
            }
          else
            @filters << lambda { |document|
              UrlFilters.send(filter, document, args)
            }
          end
        when Class
          if args.nil?
            if filter.respond_to?(:instance)
              filter_instance = filter.instance
            else
              filter_instance = filter.new
            end
          else
            filter_instance = filter.new(args)
          end
          @filters << lambda { |document|
            filter_instance.apply(document)
          }
        end
      end

      def apply(document)
        @filters.each { |filter|
          return nil unless filter.call(document)
        }
        return document
      end
    end

    # takes care of a list of all Urls visited during a crawl, to avoid
    # indexing pages more than once
    # implemented as a thread safe singleton as it has to be shared
    # between all crawler threads
    class VisitedUrlFilter
      include MonitorMixin, Singleton
      def initialize
        @visited_urls = Set.new
        super
      end

      # return document if this document's url has not been visited yet,
      # nil otherwise
      def apply(document)
        synchronize do
          @visited_urls.add?(document.uri.to_s) ? document : nil 
        end
      end
    end


    # base class for url inclusion / exclusion filters
    class PatternFilter
      # takes an Array of Regexps, or nil to disable the filter
      def initialize(args=nil)
        unless args.nil?
          @patterns = []
          if args.respond_to? :each
            args.each { |pattern| 
              # cloning because unsure if regexps are thread safe...
              @patterns << pattern.clone
            }
          else
            @patterns << args.clone
          end
        end
      end
    end
    class UrlExclusionFilter < PatternFilter
      # returns nil if any of the patterns matches it's URI,
      # the document itself otherwise
      def apply(document)
        return document unless @patterns
        @patterns.each { |p|
          return nil if document.uri.to_s =~ p
        }
        return document
      end
    end
    class UrlInclusionFilter < PatternFilter
      # returns the document if any of the patterns matches it's URI,
      # nil otherwise
      def apply(document)
        return document unless @patterns
        @patterns.each { |p|
          return document if document.uri.to_s =~ p
        }
        return nil
      end
    end

    # returns nil if any of the patterns matches it's path,
    # the document itself otherwise. Applied to real files only.
    class PathExclusionFilter < PatternFilter
      def apply(document)
        return document unless (@patterns && document.file?)
        @patterns.each { |p|
          return nil if document.uri.path =~ p
        }
        return document
      end
    end
    # returns the document if any of the patterns matches it's path,
    # nil otherwise. Applied to real files only
    class PathInclusionFilter < PatternFilter
      def apply(document)
        return document unless (@patterns && document.file?)
        @patterns.each { |p|
          return document if document.uri.path =~ p
        }
        return nil
      end
    end


    # checks redirect count of the given document
    # takes it out of the chain if number of redirections exceeds the
    # max_redirects setting
    def UrlFilters.maximum_redirect_filter(document, max_redirects)
      return nil if document.respond_to?(:redirections) && document.redirections > max_redirects
      return document
    end

    # expands both href="/path/xyz.html" and href="affe.html"
    # to full urls
    def UrlFilters.fix_relative_uri(document)
      #return nil unless document.uri.scheme.nil? || document.uri.scheme =~ /^https?/i
      ref = document.referring_uri
      return document unless ref
      uri = document.uri
      uri.scheme = ref.scheme unless uri.scheme
      uri.host = ref.host unless uri.host
      uri.port = ref.port unless uri.port || ref.port==ref.default_port
      uri.path = ref.path unless uri.path
      
      if uri.path !~ /^\//
        ref_path = ref.path || '/'
        ref_path << '/' if ref_path.empty?
        uri.path = ref_path[0..ref_path.rindex('/')] + uri.path
      end 
      return document
    rescue
      p document
      p document.uri
    end

    def UrlFilters.hostname_filter(document, include_hosts)
      return document if include_hosts.include?(document.uri.host)
      return nil
    end

    def UrlFilters.normalize_uri(document)
      document.uri.fragment = nil
      # document.uri.query = nil
      # append index document if configured and path ends with a slash
      if RDig.config.index_document && document.uri.path =~ /\/$/
        document.uri.path << RDig.config.index_document
      end
      return document
    end

    def UrlFilters.scheme_filter_file(document)
      return document if (document.uri.scheme.nil? || document.uri.scheme =~ /^file$/i)
      nil
    end
    def UrlFilters.scheme_filter_http(document)
      return document if (document.uri.scheme.nil? || document.uri.scheme =~ /^https?$/i)
      nil
    end

  end
end
