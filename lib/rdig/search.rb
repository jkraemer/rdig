module RDig
  module Search

    # This class is used to search the index.
    # Call RDig::searcher to retrieve an instance ready for use.
    class Searcher
      include Ferret::Search
      
      # the query parser used to parse query strings
      attr_reader :query_parser
  
      # takes the ferret section of the rdig configuration as a parameter.
      def initialize(settings)
        @ferret_config = settings
        @query_parser = Ferret::QueryParser.new(settings.marshal_dump)
        ferret_searcher
      end
  
      # returns the Ferret::Search::IndexSearcher instance used internally.    
      def ferret_searcher
        if @ferret_searcher and !@ferret_searcher.reader.latest?
          # reopen searcher
          @ferret_searcher.close
          @ferret_searcher = nil
        end
        unless @ferret_searcher
          @ferret_searcher = Ferret::Search::Searcher.new(@ferret_config.path)
          @query_parser.fields = @ferret_searcher.reader.field_names.to_a
        end
        @ferret_searcher
      end
  
      # run a search. 
      # +query+ usually will be a user-entered string. See the Ferret query 
      # language[http://ferret.davebalmain.com/api/classes/Ferret/QueryParser.html]
      # for more information on queries.
      # A Ferret::Search::Query instance may be given, too.
      # 
      # Otions are:
      # first_doc:: first document in result list to retrieve (0-based). The default is 0.
      # num_docs:: number of documents to retrieve. The default is 10.
      def search(query, options={})
        result = {}
        query = query_parser.parse(query) if query.is_a?(String)
        puts "Query: #{query}"
        results = []
        searcher = ferret_searcher
        result[:hitcount] = searcher.search_each(query, options) do |doc_id, score|
          doc = searcher[doc_id]
          results << { :score => score, 
                       :title => doc[:title], 
                       :url => doc[:url], 
                       :extract => build_extract(doc[:data]) }
        end
        result[:list] = results
        result
      end
  
      def build_extract(data)
        (data && data.length > 200) ? data[0..200] : data      
      end
  
    end
  
  #  class SearchResult < OpenStruct
  #    def initialize(doc, score)
  #      self.score = score
  #      self.title = doc[:title]
  #      self.url = doc[:url]
  #      self.extract = doc[:content][0..200]
  #    end
  #  end

     
  end
end
