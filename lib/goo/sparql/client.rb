require 'sparql/client'
require 'net/http'

RSPARQL = SPARQL
module Goo
  module SPARQL
    class Client < RSPARQL::Client
      def put_triples(graph,file_path,mime_type=nil)
        return RestClient.put "#{url.to_s}#{graph.to_s}",
                               File.read(file_path) ,
                               :content_type => mime_type
      end
      def append_triples(graph,data,mime_type=nil)
        return RestClient.post "#{url.to_s}",
                               :graph => graph.to_s,
                               :data => data ,
                               :content_type => mime_type
      end
      def append_triples_from_file(graph,file_path,mime_type=nil)
        return RestClient.post "#{url.to_s}",
                               :graph => graph.to_s,
                               :data => File.read(file_path) ,
                               :content_type => mime_type
      end
      def delete_graph(graph)
        return RestClient.delete "#{url.to_s}#{graph.to_s}"
      end
    end
  end
end
