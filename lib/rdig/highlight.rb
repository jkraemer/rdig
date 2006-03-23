module RDig
  module Search
    
    # beginning of a port of the Query term highlighter from Lucene contrib
    class Highlighter
      def initialize
        @analyzer = RDig.config.ferret.analyzer
      end
      def best_fragments(scorer, text, max_fragments = 1)
        token_stream = @analyzer.token_stream('body', text)
        frag_texts = []
        get_best_text_fragments(token_stream, text, max_fragments).each { |frag|
          frag_texts << frag.to_s if (frag && frag.score > 0)
        }
        return frag_texts
      end

      def get_best_text_fragments(token_stream, text, max_fragments)
        
      end
    end
    
  end
end
