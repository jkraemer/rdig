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
 
  # todo support at least pdf, too
  module ContentExtractors

    def ContentExtractors.process(content, content_type)
      case content_type
      when /^(text\/(html|xml)|application\/(xhtml\+xml|xml))/
        return HtmlContentExtractor.process(content)
      else
        puts "unable to handle content type #{content_type}"
      end
      return nil
    end

    class HtmlContentExtractor

      # returns: 
      # { :content => 'extracted clear text',
      #   :meta => { :title => 'Title' },
      #   :links => [array of urls] }
      def self.process(content)
        result = { :title => '' }
        tag_soup = BeautifulSoup.new(content)
        the_title_tag = title_tag(tag_soup)
        result[:title] = the_title_tag.string.strip if the_title_tag
        result[:links] = extract_links(tag_soup)
        content = ''

        # links sollten aber von ganzen dokument bezogen werden, nicht bloss vom content
        process_child = lambda { |child|
          if child.is_a? NavigableString
            value = self.strip_comments(child)
            value.strip!
            unless value.empty?
              content << value
              content << ' '
            end
          elsif child.string  # it's a Tag, and it has some content string
            value = child.string.strip 
            unless value.empty?
              content << value
              content << ' '
            end
          else
            child.children(&process_child)
          end
          true
        }
        content_element(tag_soup).children(&process_child)
        result[:content] = content.strip #CGI.unescapeHTML(content.strip)
        return result
      end

      # extracts the href attributes of all a tags, except 
      # internal links like <a href="#top">
      def self.extract_links(tagsoup)
        tagsoup.find_all('a').map { |link|
          CGI.unescapeHTML(link['href']) if (link['href'] && link['href'] !~ /^#/)
        }.compact
      end

      def self.title_tag(tagsoup)
        if RDig.config.content_extraction.html.title_tag_selector
          RDig.config.content_extraction.html.title_tag_selector.call(tagsoup)
        else 
          tagsoup.html.head.title
        end
      end

      def self.content_element(tagsoup)
        if RDig.config.content_extraction.html.content_tag_selector
          RDig.config.content_extraction.html.content_tag_selector.call(tagsoup)
        else
          tagsoup.html.body
        end
      end

      def self.strip_comments(string)
        string.gsub(Regexp.new('<!--.*?-->', Regexp::MULTILINE, 'u'), '')
      end
    end

  end
end
