#!/usr/bin/env ruby

#--
# Copyright (c) 2006 Jens Kraemer
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++
#

RDIGVERSION = '0.1.0'


require 'thread'
require 'thwait'
require 'singleton'
require 'monitor'
require 'ostruct'
require 'uri'
require 'cgi'
require 'set'
require 'net/http'
require 'getoptlong'

begin
  require 'rubyful_soup'
  require 'ferret'
rescue LoadError
  require 'rubygems'
  require 'rubyful_soup'
  require 'ferret'
end

require 'htmlentities/htmlentities'

require 'rdig/http_client'
require 'rdig/content_extractors'
require 'rdig/url_filters'
require 'rdig/search'
require 'rdig/index'
require 'rdig/crawler'

$KCODE = 'u'
require 'jcode'

# See README for basic usage information
module RDig

  class << self

    # the filter chain each URL has to run through before being crawled.
    def filter_chain
      @filter_chain ||= [
        { :maximum_redirect_filter => :max_redirects },
        :fix_relative_uri,
        :normalize_uri,
        { :hostname_filter => :include_hosts },
        { RDig::UrlFilters::UrlInclusionFilter => :include_documents },
        { RDig::UrlFilters::UrlExclusionFilter => :exclude_documents },
        RDig::UrlFilters::VisitedUrlFilter 
      ]
    end

    def application
      @application ||= Application.new
    end

    def searcher
      @searcher ||= Search::Searcher.new(config.ferret)
    end

    # RDig configuration
    #
    # may be used with a block:
    #   RDig.configuration do |config| ...
    #
    # see doc/examples/config.rb for a commented example configuration
    def configuration
      if block_given?
        yield configuration
      else
        @config ||= OpenStruct.new(
          :crawler           => OpenStruct.new(
            :start_urls        => [ "http://localhost:3000/" ],
            :include_hosts     => [ "localhost" ],
            :include_documents => nil,
            :exclude_documents => nil,
            :index_document    => nil,
            :num_threads       => 2,
            :max_redirects     => 5,
            :wait_before_leave => 10
          ),
          :content_extraction  => OpenStruct.new(
            # settings for html content extraction
            :html => OpenStruct.new(
              # select the html element that contains the content to index
              # by default, we index all inside the body tag:
              :content_tag_selector => lambda { |tagsoup|
                tagsoup.html.body
              },
              # select the html element containing the title 
              :title_tag_selector         => lambda { |tagsoup|
                tagsoup.html.head.title
              }
            )
          ),
          :ferret                => OpenStruct.new( 
            :path                => "index/", 
            :create              => true,
            :handle_parse_errors => true,
            :analyzer            => Ferret::Analysis::StandardAnalyzer.new,
            :occur_default       => Ferret::Search::BooleanClause::Occur::MUST
          )
        )
      end
    end
    alias config configuration
    
  end

  class Application

    OPTIONS = [
      ['--config',   '-c', GetoptLong::REQUIRED_ARGUMENT,
        "Read aplication configuration from CONFIG."],
      ['--help',     '-h', GetoptLong::NO_ARGUMENT,
        "Display this help message."],
      ['--query',   '-q', GetoptLong::REQUIRED_ARGUMENT,
        "Execute QUERY."],
      ['--version',  '-v', GetoptLong::NO_ARGUMENT,
       	"Display the program version."],
    ]

    # Application options from the command line
    def options
      @options ||= OpenStruct.new
    end
    
    # Display the program usage line.
    def usage
      puts "rdig -c configfile {options}"
    end
    
    # Display the rake command line help.
    def help
      usage
      puts
      puts "Options are ..."
      puts
      OPTIONS.sort.each do |long, short, mode, desc|
        if mode == GetoptLong::REQUIRED_ARGUMENT
          if desc =~ /\b([A-Z]{2,})\b/
            long = long + "=#{$1}"
          end
        end
        printf "  %-20s (%s)\n", long, short
        printf "      %s\n", desc
      end
    end

    # Return a list of the command line options supported by the
    # program.
    def command_line_options
      OPTIONS.collect { |lst| lst[0..-2] }
    end

    # Do the option defined by +opt+ and +value+.
    def do_option(opt, value)
      case opt
      when '--help'
        help
        exit
      when '--config'
        options.config_file = value
      when '--query'
        options.query = value
      when '--version'
        puts "rdig, version #{RDIGVERSION}"
        exit
      else
        fail "Unknown option: #{opt}"
      end 
    end

    # Read and handle the command line options.
    def handle_options
      opts = GetoptLong.new(*command_line_options)
      opts.each { |opt, value| do_option(opt, value) }
    end

    # Load the configuration
    def load_configfile
      load File.expand_path(options.config_file)
    end

    # Run the +rdig+ application.
    def run
      handle_options
      begin
        load_configfile
      rescue
        puts $!.backtrace
        fail "No Configfile found!\n#{$!}"
        
      end    

      if options.query
        # query the index
        puts "executing query >#{options.query}<"
        results = RDig.searcher.search(options.query)
        puts "total results: #{results[:hitcount]}"
        results[:list].each { |result|
          puts <<-EOF
#{result[:url]}
  #{result[:title]}
  #{result[:extract]}

          EOF
        }
      else
        # rebuild index
        @crawler = Crawler.new
        @crawler.run
      end
    end
  end
end
