module Goo
  module SPARQL
    module Queries
      def self.model_exist(model,id=nil,store=:main)
        id = id || model.id
        so = Goo.sparql_query_client(store).ask.whether([id, RDF.type, model.class.uri_type])
        return so.true?
      end
    end #queries
  end #SPARQL
end #Goo
