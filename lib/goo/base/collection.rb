require_relative "settings/settings"

module Goo
  module Base
    class Collection
      def initialize(uri)
        @uri = uri
      end

      def alias_attributes(origin,dest)
        graph_insert = [origin.to_ntriples, 
                        Goo.vocabulary(:rdfs)[:subPropertyOf].to_ntriples,
                        dest.to_ntriples, "."]
        data = graph_insert.join " "
        Goo.sparql_data_client.append_triples(@uri, data,"application/x-turtle")
      end
    end
  end
end
