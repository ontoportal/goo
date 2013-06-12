require 'sparql/client'
require 'net/http'

RSPARQL = SPARQL
module Goo
  module SPARQL
    class Client < RSPARQL::Client
      def put_triples(graph,file_path,mime_type=nil)
        params = {
          method: :put,
          url: "#{url.to_s}#{graph.to_s}",
          payload: File.read(file_path),
          headers: {content_type: mime_type},
          timeout: -1
        }
        return RestClient::Request.execute(params)
      end

      def append_triples(graph,data,mime_type=nil)
        params = {
          method: :post,
          url: "#{url.to_s}",
          payload: {
            graph: graph.to_s,
            data: data,
            "mime-type" => mime_type
          },
          headers: {"mime-type" => mime_type},
          timeout: -1
        }
        return RestClient::Request.execute(params)
      end

      def append_triples_from_file(graph,file_path,mime_type=nil)
        params = {
          method: :post,
          url: "#{url.to_s}",
          payload: {
           graph: graph.to_s,
           data: File.read(file_path),
           "mime-type" => mime_type
          },
          headers: {"mime-type" => mime_type},
          timeout: -1
        }
        return RestClient::Request.execute(params)
      end

      def delete_graph(graph)
        params = {
          method: :delete,
          url: "#{url.to_s}#{graph.to_s}",
          timeout: -1
        }
        return RestClient::Request.execute(params)
      end
    end
  end
end
