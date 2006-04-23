# override some methods concered with entity resolving
# to convert them to strings
class BeautifulStoneSoup
  # resolve unknown html entities using the htmlentities lib
  alias :orig_unknown_entityref :unknown_entityref
  def unknown_entityref(ref)
    if HTMLEntities::MAP.has_key?(ref)
      handle_data [HTMLEntities::MAP[ref]].pack('U')
    else
      orig_unknown_entityref ref
    end
  end

  # resolve numeric entities to utf8
  def handle_charref(ref)
    handle_data( ref.gsub(/([0-9]{1,7})/) { 
                            [$1.to_i].pack('U') 
                    }.gsub(/x([0-9a-f]{1,6})/i) { 
                            [$1.to_i(16)].pack('U') 
                    } )
  end
end

module RDig
 
  # Contains classes which are used for extracting content and meta data from
  # various content types.
  module ContentExtractors

    # process the given +content+ depending on it's +content_type+.
    def self.process(content, content_type)
      ContentExtractor.process(content, content_type)
      #      case content_type
      #when /^(text\/(html|xml)|application\/(xhtml\+xml|xml))/
      #  return HtmlContentExtractor.process(content)
      #when /^application\/.+pdf/
      #  return PdfContentExtractor.process(content) unless RDig.config.content_extraction.pdf.disabled
      #else
      #  puts "unable to handle content type #{content_type}"
      #end
      #return nil
    end

    # Base class for Content Extractors.
    # Extractors inheriting from this class will be auto-discovered and used
    # when can_do returns true
    class ContentExtractor
      
      def self.inherited(extractor)
        super(extractor)
        puts("discovered content extractor class: #{extractor}")
        self.extractors << extractor
      end

      def self.extractors; @@extractors ||= [] end
      def self.extractor_instances
        @@extractor_instances ||= extractors.map { |ex_class| 
          ex_class.new(RDig.configuration.content_extraction) 
        }
      end
      
      def self.process(content, content_type)
        self.extractor_instances.each { |extractor|
          return extractor.process(content) if extractor.can_do(content_type)
        }
        puts "unable to handle content type #{content_type}"
        nil
      end

      def initialize(config)
        @config = config
      end

      def can_do(content_type)
        content_type =~ @pattern
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

    # Extract text from pdf content.
    #
    # Requires the pdftotext and pdfinfo utilities from the 
    # xpdf-utils package
    # (on debian and friends do 'apt-get install xpdf-utils')
    #
    class PdfContentExtractor < ContentExtractor
      include ExternalAppHelper
      
      def initialize(config)
        super(config)
        @pattern = /^application\/pdf/
        @pdftotext = 'pdftotext'
        @pdfinfo = 'pdfinfo'
        @available = true
        [ @pdftotext, @pdfinfo].each { |program|
          unless %x{#{program} -h 2>&1} =~ /Copyright 1996/ 
            @available = false 
            break
          end
        }
      end
 
      def process(content)
        result = {}
        as_file(content) do |file|
          result[:content] = get_content(file.path).strip
          result[:title] = get_title(file.path)
        end
        result
      end

      def get_content(path_to_tempfile)
        %x{#{@pdftotext} -enc UTF-8 '#{path_to_tempfile}' -}
      end
      
      # extracts the title from pdf meta data
      # needs pdfinfo
      # returns the title or nil if no title was found
      def get_title(path_to_tempfile)
        %x{#{@pdfinfo} -enc UTF-8 '#{path_to_tempfile}'} =~ /title:\s+(.*)$/i ? $1.strip : nil
      rescue
      end
    end

    # Extract text from word documents
    #
    # Requires the wvHtml utility
    # (on debian and friends do 'apt-get install wv')
    class WordContentExtractor < ContentExtractor
      include ExternalAppHelper
      
      def initialize(config)
        super(config)
        @wvhtml = 'wvHtml'
        @pattern = /^application\/msword/
        # html extractor for parsing wvHtml output
        @html_extractor = HtmlContentExtractor.new(OpenStruct.new(
            :html => OpenStruct.new(
              :content_tag_selector => lambda { |tagsoup|
                tagsoup.html.body
              },
              :title_tag_selector         => lambda { |tagsoup|
                tagsoup.html.head.title
              }
            )))

        # TODO: besser: if $?.exitstatus == 127 (not found)
        @available = %x{#{@wvhtml} -h 2>&1} =~ /Dom Lachowicz/
      end
      
      def process(content)
        result = {}
        as_file(content) do |file|  
          result = @html_extractor.process(%x{#{@wvhtml} --charset=UTF-8 '#{file.path}' -})
        end
        return result || {}
      end
      
    end

    # extracts title, content and links from html documents
    class HtmlContentExtractor < ContentExtractor

      def initialize(config)
        super(config)
        @pattern = /^(text\/(html|xml)|application\/(xhtml\+xml|xml))/
      end

      # returns: 
      # { :content => 'extracted clear text',
      #   :meta => { :title => 'Title' },
      #   :links => [array of urls] }
      def process(content)
        result = { }
        tag_soup = BeautifulSoup.new(content)
        result[:title] = extract_title(tag_soup)
        result[:links] = extract_links(tag_soup)
        result[:content] = extract_content(tag_soup)
        return result
      end

      # Extracts textual content from the HTML tree.
      #
      # - First, the root element to use is determined using the 
      # +content_element+ method, which itself uses the content_tag_selector
      # from RDig.configuration.
      # - Then, this element is processed by +extract_text+, which will give
      # all textual content contained in the root element and all it's
      # children.
      def extract_content(tag_soup)
        content = ''
        ce = content_element(tag_soup)
        ce.children { |child| 
          extract_text(child, content)
        } unless ce.nil?
        return content.strip
      end

      # extracts the href attributes of all a tags, except 
      # internal links like <a href="#top">
      def extract_links(tagsoup)
        tagsoup.find_all('a').map { |link|
          CGI.unescapeHTML(link['href']) if (link['href'] && link['href'] !~ /^#/)
        }.compact
      end

      # Extracts the title from the given html tree
      def extract_title(tagsoup)
        the_title_tag = title_tag(tagsoup)
        if the_title_tag.is_a? String
          the_title_tag
        else
          title = ''
          extract_text(the_title_tag, title)
          title.strip
        end
      end

      # Recursively extracts all text contained in the given element, 
      # and appends it to content.
      def extract_text(element, content='')
        return nil if element.nil?
        if element.is_a? NavigableString
          value = strip_comments(element)
          value.strip!
          unless value.empty?
            content << value
            content << ' '
          end
        elsif element.string  # it's a Tag, and it has some content string
          value = element.string.strip 
          unless value.empty?
            content << value
            content << ' '
          end
        else
          element.children { |child|
            extract_text(child, content)
          }
        end
      end

      # Returns the element to extract the title from.
      #
      # This may return a string, e.g. an attribute value selected from a meta
      # tag, too.
      def title_tag(tagsoup)
        if @config.html.title_tag_selector
          @config.html.title_tag_selector.call(tagsoup)
        else 
          tagsoup.html.head.title
        end
      end

      # Retrieve the root element to extract document content from
      def content_element(tagsoup)
        if @config.html.content_tag_selector
          @config.html.content_tag_selector.call(tagsoup)
        else
          tagsoup.html.body
        end
      end

      # Return the given string minus all html comments
      def strip_comments(string)
        string.gsub(Regexp.new('<!--.*?-->', Regexp::MULTILINE, 'u'), '')
      end
    end

  end
end
