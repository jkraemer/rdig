module RDig
 
  # Contains classes which are used for extracting content and meta data from
  # various content types.
  module ContentExtractors

    # process the given +content+ depending on it's +content_type+.
    def self.process(content, content_type)
      ContentExtractor.process(content, content_type)
    end

    # Base class for Content Extractors.
    # Extractors inheriting from this class will be auto-discovered and used
    # when can_do returns true
    class ContentExtractor
      
      def self.inherited(extractor)
        super(extractor)
        self.extractors << extractor
      end

      def self.extractors; @@extractors ||= [] end
      def self.extractor_instances
        @@extractor_instances ||= extractors.map { |ex_class| 
          RDig.logger.info "initializing content extractor: #{ex_class}"
          ex = nil
          begin
            ex = ex_class.new(RDig.configuration.content_extraction)
          rescue Exception
            RDig.logger.error "error: #{$!.message}\n#{$!.backtrace.join("\n")}"
          end
          ex
        }.compact
      end
      
      def self.process(content, content_type)
        self.extractor_instances.each { |extractor|
          return extractor.process(content) if extractor.can_do(content_type)
        }
        puts "unable to handle content type #{content_type}"
      end

      def initialize(config)
        @config = config
      end

      def can_do(content_type)
        @pattern && content_type =~ @pattern
      end
    end


    # to be used by concrete implementations having a get_content class method
    # that takes a path to a file and return the textual content extracted from
    # that file.
    module ExternalAppHelper
      def process(content)
        result = {}
        as_file(content) do |file|
          result[:content] = get_content(file.path).strip
        end
        result
      end
      
      def as_file(content)
        file = Tempfile.new('rdig')
        file << content
        file.close
        yield file
        file.delete
      end

      # setting @available according to presence of external executables
      # in initializer of ContentExtractor is needed to make this work
      def can_do(content_type)
        @available and super(content_type)
      end
    end

  end
end

# load content extractors
Dir["#{File.expand_path(File.dirname(__FILE__))}/content_extractors/**/*.rb"].each do |f|
  begin
    require f
  rescue LoadError
    RDig::logger.error "could not load #{f}: #{$!}"
  end
end
