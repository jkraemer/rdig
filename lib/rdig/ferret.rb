module RDig

  module Search
    # used to search the index
    class Searcher
      include Ferret::Search
  
      attr_reader :query_parser
  
      def initialize(settings)
        @ferret_config = settings
        @query_parser = Ferret::QueryParser.new('*', settings.marshal_dump)
        ferret_searcher
      end
  
      def ferret_searcher
        if @ferret_searcher and !@ferret_searcher.reader.latest?
          # reopen searcher
          @ferret_searcher.close
          @ferret_searcher = nil
        end
        unless @ferret_searcher
          @ferret_searcher = IndexSearcher.new(@ferret_config.path)
          @query_parser.fields = @ferret_searcher.reader.get_field_names.to_a
        end
        @ferret_searcher
      end
  
      # options:
      # first_doc: first document in result list to retrieve (0-based)
      # num_docs : number of documents to retrieve
      def search(query, options={})
        result = {}
        query = query_parser.parse(query) if query.is_a?(String)
        puts "Query: #{query}"
        hits = ferret_searcher.search(query, options)
        result[:hitcount] = hits.total_hits
        results = []
        hits.each { |doc_id,score|
          doc = ferret_searcher.reader.get_document doc_id
          results << { :score => score, 
                      :title => doc['title'], 
                      :url => doc['url'], 
                      :extract => build_extract(doc['data']) }
        }
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

  module Index
  
    # used by the crawler to build the ferret index
    class Indexer
      include MonitorMixin, Ferret::Index, Ferret::Document
      
      def initialize(settings)
        @ferret_config = settings
        @index_writer = IndexWriter.new(@ferret_config.path,
                                        :create => @ferret_config.create)
        super() # scary, MonitorMixin won't initialize if we don't call super() here (parens matter)
      end
      
      def add_to_index(document)
        puts "add to index: #{document.uri.to_s}"
        doc = Ferret::Document::Document.new
        doc << Field.new("url", document.url, 
                        Field::Store::YES, Field::Index::UNTOKENIZED)
        doc << Field.new("title", document.title, 
                        Field::Store::YES, Field::Index::TOKENIZED)
        doc << Field.new("data",  document.body, 
                        Field::Store::YES, Field::Index::TOKENIZED)
        synchronize do
          @index_writer << doc
        end
      end
      alias :<< :add_to_index
  
      def close
        @index_writer.optimize
        @index_writer.close
        @index_writer = nil
      end
    end
    
  end
end
