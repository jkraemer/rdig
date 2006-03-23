module RDig
  module Index
  
    # used by the crawler to build the ferret index
    class Indexer
      include MonitorMixin, Ferret::Index, Ferret::Document
      
      def initialize(settings)
        #@ferret_config = settings
        @index_writer = IndexWriter.new(settings.path,
                                        :create   => settings.create,
                                        :analyzer => settings.analyzer)
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
