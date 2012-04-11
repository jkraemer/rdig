module RDig
  module ContentExtractors
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

  end
end
