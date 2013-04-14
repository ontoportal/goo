require 'sparql/client'
require 'sparql/client/query'

module Goo
  module SPARQL
    module Queries
      def self.model_exist(model,id=nil,store=:main)
        id = id || model.id
        so = Goo.sparql_query_client(store).ask.whether([id, RDF.type, model.class.uri_type])
        return so.true?
      end

      ##
      # always a list of attributes with subject == id
      ##
      def self.model_load(*options)
        options = options.last
        ids = options[:ids]
        klass = options[:klass]
        incl = options[:include]
        store = options[:store] || :main

        variables = [:id]

        if incl
          binding.pry
        end
        patterns = [ :id ,RDF.type, klass.uri_type]
        filter_id = []
        ids.each do |id|
          filter_id << "?id = #{id.to_ntriples.to_s}"
        end
        filter_id_str = filter_id.join " || "

        binding.pry
        client = Goo.sparql_query_client(store)
        select = client.select(*variables).distinct()
        binding.pry
        select.where(patterns)
        select.filter(filter_id_str)
        binding.pry
      end



    end #queries
  end #SPARQL
end #Goo
