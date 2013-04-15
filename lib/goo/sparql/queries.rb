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
        models = options[:models]
        store = options[:store] || :main

        if ids and models
          raise ArgumentError, "Inconsistent call , either models or IDs"
        end
        if models
          models.each do |m|
            raise ArgumentError, "To load attributes the resource must be persistent" unless m.persistent?
          end
        end

        models_by_id = {}
        if models
          ids = []
          models.each do |m|
            ids << m.id
            models_by_id[m.id] = m
          end
        else
          ids.each do |id|
            models_by_id[id] = klass.new
            models_by_id[id].id = id
          end
        end

        variables = [:id]

        patterns = [[ :id ,RDF.type, klass.uri_type]]
        if incl
          #make it deterministic
          incl = incl.to_a.sort
          variables.concat(incl)
          incl.each do |attr|
            predicate = klass.attribute_uri(attr)
            patterns << [ :id , predicate , attr]
          end
        end
        filter_id = []
        ids.each do |id|
          filter_id << "?id = #{id.to_ntriples.to_s}"
        end
        filter_id_str = filter_id.join " || "

        client = Goo.sparql_query_client(store)
        select = client.select(*variables).distinct()
        select.where(*patterns)
        select.filter(filter_id_str)

        found = Set.new
        list_attributes = klass.attributes(:list)
        select.each_solution do |sol|
          found.add(sol[:id])
          id = sol[:id]
          variables.each do |v|
            next if v == :id
            #group for multiple values
            object = sol[v].object
            if list_attributes.include?(v)
              pre = models_by_id[id].send("#{v}")
              object = !pre ? [object] : (pre.dup << object)
            end
            models_by_id[id].send("#{v}=",object, on_load: true)
          end
        end

        #remove from models_by_id elements that were not touched
        models_by_id.select! { |k,m| found.include?(k) }

        if options[:ids] #newly loaded
          models_by_id.each do |k,m|
            m.persistent=true
          end
        end
        return models_by_id
      end

    end #queries
  end #SPARQL
end #Goo
