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
 
  # Contains Classes which are used for extracting content and meta data from
  # various content types.
  #
  # TODO: support at least pdf, too.
  module ContentExtractors

    # process the given +content+ depending on it's +content_type+.
    def ContentExtractors.process(content, content_type)
      case content_type
      when /^(text\/(html|xml)|application\/(xhtml\+xml|xml))/
        return HtmlContentExtractor.process(content)
      else
        puts "unable to handle content type #{content_type}"
      end
      return nil
    end

    # extracts title, content and links from html documents
    class HtmlContentExtractor

      # returns: 
      # { :content => 'extracted clear text',
      #   :meta => { :title => 'Title' },
      #   :links => [array of urls] }
      def self.process(content)
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
      def self.extract_content(tag_soup)
        content = ''
        content_element(tag_soup).children { |child| 
          extract_text(child, content)
        }
        return content.strip
      end

      # extracts the href attributes of all a tags, except 
      # internal links like <a href="#top">
      def self.extract_links(tagsoup)
        tagsoup.find_all('a').map { |link|
          CGI.unescapeHTML(link['href']) if (link['href'] && link['href'] !~ /^#/)
        }.compact
      end

      # Extracts the title from the given html tree
      def self.extract_title(tagsoup)
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
      def self.extract_text(element, content='')
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
      def self.title_tag(tagsoup)
        if RDig.config.content_extraction.html.title_tag_selector
          RDig.config.content_extraction.html.title_tag_selector.call(tagsoup)
        else 
          tagsoup.html.head.title
        end
      end

      # Retrieve the root element to extract document content from
      def self.content_element(tagsoup)
        if RDig.config.content_extraction.html.content_tag_selector
          RDig.config.content_extraction.html.content_tag_selector.call(tagsoup)
        else
          tagsoup.html.body
        end
      end

      # Return the given string minus all html comments
      def self.strip_comments(string)
        string.gsub(Regexp.new('<!--.*?-->', Regexp::MULTILINE, 'u'), '')
      end
    end

  end
end
