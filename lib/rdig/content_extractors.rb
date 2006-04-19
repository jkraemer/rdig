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
        @@extractor_instances ||= extractors.map { |ex_class| ex_class.new }
      end
      
      def self.process(content, content_type)
        self.extractor_instances.each { |extractor|
          return extractor.process(content) if extractor.can_do(content_type)
        }
        puts "unable to handle content type #{content_type}"
        nil
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

      def available
        if @available.nil?
          @available = !find_executable(@executable).nil?
        end
        @available
      end

      def can_do(content_type)
        available and super(content_type)
      end
    end

    # Extract text from pdf content.
    #
    # Requires the pdftotext utility from the xpdf-utils package
    # (on debian and friends do 'apt-get install xpdf-utils')
    #
    # TODO: use pdfinfo to get title from document
    class PdfContentExtractor < ContentExtractor
      include ExternalAppHelper
      
      def initialize
        @executable = 'pdftotext'
        @pattern = /^application\/pdf/
      end
      
      def get_content(path_to_tempfile)
        %x{#{@executable} '#{path_to_tempfile}' -}
      end
    end

    # Extract text from word documents
    #
    # Requires the antiword utility
    # (on debian and friends do 'apt-get install antiword')
    class WordContentExtractor < ContentExtractor
      include ExternalAppHelper
      
      def initialize
        @executable = 'wvHtml'
        @pattern = /^application\/msword/
        @html_extractor = HtmlContentExtractor.new
      end
      
      def process(content)
        result = {}
        as_file(content) do |infile|  
          outfile = Tempfile.new('rdig')
          outfile.close
          %x{#{@executable} --targetdir='#{File.dirname(outfile.path)}' '#{infile.path}' '#{File.basename(outfile.path)}'}
          File.open(outfile.path) do |html|
            result = @html_extractor.process(html.read)
          end
          outfile.delete
        end
        return result || {}
      end
      
    end

    # extracts title, content and links from html documents
    class HtmlContentExtractor < ContentExtractor

      def initialize
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
        content_element(tag_soup).children { |child| 
          extract_text(child, content)
        }
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
        title = ''
        the_title_tag = title_tag(tagsoup)
        if the_title_tag.is_a? String
          the_title_tag
        else
          extract_text(the_title_tag).strip if the_title_tag
        end
      end

      # Recursively extracts all text contained in the given element, 
      # and appends it to content.
      def extract_text(element, content='')
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
        if RDig.config.content_extraction.html.title_tag_selector
          RDig.config.content_extraction.html.title_tag_selector.call(tagsoup)
        else 
          tagsoup.html.head.title
        end
      end

      # Retrieve the root element to extract document content from
      def content_element(tagsoup)
        if RDig.config.content_extraction.html.content_tag_selector
          RDig.config.content_extraction.html.content_tag_selector.call(tagsoup)
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
