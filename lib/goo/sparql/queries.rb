require 'sparql/client'
require 'sparql/client/query'

module Goo
  module SPARQL
    module Queries
      def self.model_exist(model,id=nil,store=:main)
        id = id || model.id
        so = Goo.sparql_query_client(store).ask.from(model.graph).
          whether([id, RDF.type, model.class.uri_type])
        return so.true?
      end

      def self.query_pattern(klass,attr,value=nil)
        if klass.inverse?(attr)
          inverse_opts = klass.inverse_opts(attr)
          on_klass = inverse_opts[:on]
          inverse_klass = on_klass.respond_to?(:model_name) ? on_klass: Goo.models[on_klass]
          if inverse_klass.collection?(inverse_opts[:attribute])
            #inverse on collection - need to retrieve graph
            #graph_items_collection = attr
            #inverse_klass_collection = inverse_klass
            #return [nil, nil]
            binding.pry
          end
          predicate = inverse_klass.attribute_uri(inverse_opts[:attribute])
          return [ inverse_klass.uri_type , [ value.nil? ? attr : value, predicate, :id ]]
        else
          predicate = klass.attribute_uri(attr)
          return [nil, [ :id , predicate , value.nil? ? attr : value]]
        end
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
        filters = options[:filters]
        collection = options[:collection]
        store = options[:store] || :main

        if ids and models
          raise ArgumentError, "Inconsistent call , either models or IDs"
        end
        if models
          models.each do |m|
            raise ArgumentError, 
              "To load attributes the resource must be persistent" unless m.persistent?
          end
        end

        graphs = [collection ? collection.id : klass.uri_type]
        models_by_id = {}
        if models
          ids = []
          models.each do |m|
            ids << m.id
            models_by_id[m.id] = m
          end
        elsif ids
          ids.each do |id|
            models_by_id[id] = klass.new
            models_by_id[id].id = id
          end
        else #a where without models

        end

        variables = [:id]

        patterns = [[ :id ,RDF.type, klass.uri_type]]
        optional_patterns = []
        graph_items_collection = nil
        inverse_klass_collection = nil
        if incl
          #make it deterministic
          incl = incl.to_a.sort rescue binding.pry
          variables.concat(incl)
          incl.each do |attr|
            graph, pattern = query_pattern(klass,attr)
            optional_patterns << pattern if pattern
            graphs << graph if graph
          end
        end
        if filters
          #make it deterministic - for caching
          filters = filters.to_a.sort
          filters.each do |attr,value|
            graph, pattern = query_pattern(klass,attr,value)
            patterns << pattern if pattern
            graphs << pattern if graph
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
        optional_patterns.each do |optional|
          select.optional(*[optional])
        end
        select.filter(filter_id_str)
        select.from(graphs)

        found = Set.new
        list_attributes = klass.attributes(:list)
        objects_new = {}
        select.each_solution do |sol|
          found.add(sol[:id])
          id = sol[:id]
          variables.each do |v|
            next if v == :id and models_by_id.include?(id)
            #group for multiple values
            object = sol[v] ? sol[v] : nil
            if object and  !(object.kind_of? RDF::URI)
              object = object.object
            end

            #dependent model creation
            if object.kind_of?(RDF::URI) && v != :id
              if objects_new.include?(object)
                object = objects_new[object]
              else
                range = klass.range(v)
                range_object = range.new
                range_object.id = object
                range_object.persistent = true
                object = range_object
                objects_new[object.id] = object
              end
            end

            if object and list_attributes.include?(v)
              pre = models_by_id[id].instance_variable_get("@#{v}")
              object = !pre ? [object] : (pre.dup << object)
            end
            if !models_by_id.include?(id) && v == :id
              #a where call
              klass_model = klass.new
              klass_model.id = id
              klass_model.persistent = true
              models_by_id[id] = klass_model
            end
            models_by_id[id].send("#{v}=",object, on_load: true) if v != :id
          end
        end

        if collection and klass.collection_opts.instance_of?(Symbol)
          collection_attribute = klass.collection_opts
          models_by_id.each do |id,m|
            m.send("#{collection_attribute}=", collection)
          end
        end

        if graph_items_collection
          #here we need a where call using collection
          #inverse_klass_collection.where
          #
          binding.pry
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
