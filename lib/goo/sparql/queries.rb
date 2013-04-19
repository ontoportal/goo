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

        graph = collection ? collection.id : klass.uri_type
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
        optional_patterns = []
        if incl
          #make it deterministic
          incl = incl.to_a.sort
          variables.concat(incl)
          incl.each do |attr|
            if klass.inverse?(attr)
              inverse_opts = klass.inverse_opts(attr)
              on_klass = inverse_opts[:on]
              inverse_klass = on_klass.respond_to?(:model_name) ? on_klass: Goo.models[on_class]
              predicate = inverse_klass.attribute_uri(inverse_opts[:attribute])
              optional_patterns << [ attr, predicate, :id ]
            else
              predicate = klass.attribute_uri(attr)
              optional_patterns << [ :id , predicate , attr]
            end
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
        select.from(graph)

        found = Set.new
        list_attributes = klass.attributes(:list)
        objects_new = {}
        select.each_solution do |sol|
          found.add(sol[:id])
          id = sol[:id]
          variables.each do |v|
            next if v == :id
            #group for multiple values
            object = sol[v] ? sol[v] : nil
            if object and  !(object.kind_of? RDF::URI)
              object = object.object
            end

            #dependent model creation
            if object.kind_of?(RDF::URI)
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
            models_by_id[id].send("#{v}=",object, on_load: true)
          end
        end

        if collection and klass.collection_opts.instance_of?(Symbol)
          collection_attribute = klass.collection_opts
          models_by_id.each do |id,m|
            m.send("#{collection_attribute}=", collection)
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
