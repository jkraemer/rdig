require 'net/http'

module RDig
  
  module HttpClient
    def do_get(uri, user_agent='RDig crawler')
      # Set up the appropriate http headers
      headers = { "User-Agent" => user_agent }
      result = {}
  
      begin
        Net::HTTP.start(uri.host, (uri.port or 80)) { |http|
          final_uri = uri.path 
          final_uri += ('?' + uri.query) if uri.query
          return http.get(final_uri, headers)
        }
      rescue => error
        puts error
      end
    end
  end

end

