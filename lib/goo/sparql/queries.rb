require 'sparql/client'
require 'sparql/client/query'

module Goo
  module SPARQL
    module Queries
      def self.duplicate_attribute_value?(model,attr,store=:main)
        value = model.instance_variable_get("@#{attr}")
        if !value.instance_of? Array
          so = Goo.sparql_query_client(store).ask.from(model.graph).
            whether([:id, model.class.attribute_uri(attr), value]).
            filter("?id != #{model.id.to_ntriples}")
          return so.true?
        else
          #not yet support for unique arrays
        end
      end

      def self.model_exist(model,id=nil,store=:main)
        id = id || model.id
        so = Goo.sparql_query_client(store).ask.from(model.graph).
          whether([id, RDF.type, model.class.uri_type])
        return so.true?
      end

      def self.query_pattern(klass,attr,value=nil,subject=:id)
        value = value.id if value.class.respond_to?(:model_settings)
        klass.inverse?(attr) rescue binding.pry
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
          return [ inverse_klass.uri_type , [ value.nil? ? attr : value, predicate, subject ]]
        else
          predicate = klass.attribute_uri(attr)
          return [klass.uri_type, [ subject , predicate , value.nil? ? attr : value]]
        end
      end

      def self.walk_pattern(klass, match_patterns, graphs, patterns, unions, 
                                variables, internal_variables)
        match_patterns.each do |match,in_union|
          unions << [] if in_union
          match.each do |attr,value|
            patterns_for_match(klass, attr, value, graphs, patterns,
                               unions, variables, internal_variables,
                               subject=:id,in_union=in_union)
          end
        end
      end

      def self.patterns_for_match(klass,attr,value,graphs,patterns,unions,
                                   variables,internal_variables,subject=:id,in_union=false)
        if value.respond_to?(:each)
          next_pattern = value.instance_of?(Array) ? value.first : value
          value = "internal_join_var_#{internal_variables.length}".to_sym
          internal_variables << value
        end
        graph, pattern = query_pattern(klass,attr,value,subject)
        if pattern
          if !in_union
            patterns << pattern
          else
            unions.last << pattern
          end
        end
        graphs << graph if graph
        if next_pattern
          range = klass.range(attr) 
          next_pattern.each do |next_attr,next_value|
            patterns_for_match(range, next_attr, next_value, graphs,
                  patterns, unions, variables, internal_variables, subject=value, in_union)
          end
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
        graph_match = options[:graph_match]
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
        unions = []
        optional_patterns = []
        graph_items_collection = nil
        inverse_klass_collection = nil
        incl_embed = nil
        if incl
          #make it deterministic
          incl = incl.to_a
          incl_direct = incl.select { |a| a.instance_of?(Symbol) }
          variables.concat(incl_direct)
          incl_embed = incl.select { |a| a.instance_of?(Hash) }
          binding.pry if incl_embed.length > 1
          raise ArgumentError, "Not supported case for embed" if incl_embed.length > 1
          incl.delete_if { |a| !a.instance_of?(Symbol) }
          if incl_embed.length > 0
            incl_embed = incl_embed.first
            embed_variables = incl_embed.keys.sort
            variables.concat(embed_variables)
            incl.concat(embed_variables)
          end
          incl.each do |attr|
            binding.pry if attr.instance_of? Hash
            graph, pattern = query_pattern(klass,attr)
            optional_patterns << pattern if pattern
            graphs << graph if graph
          end
        end
        if graph_match
          #make it deterministic - for caching
          internal_variables = []
          graph_match_iteration = Goo::Base::PatternIteration.new(graph_match) 
          walk_pattern(klass,graph_match_iteration,graphs,patterns,unions,
                             variables,internal_variables)
          graphs.uniq!
        end
        filter_id = []
        if ids
          ids.each do |id|
            filter_id << "?id = #{id.to_ntriples.to_s}"
          end
        end
        filter_id_str = filter_id.join " || "

        client = Goo.sparql_query_client(store)
        select = client.select(*variables).distinct()
        select.where(*patterns)
        optional_patterns.each do |optional|
          select.optional(*[optional])
        end
        select.union(*unions) if unions.length > 0

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

        #next level of embed attributes
        if incl_embed && incl_embed.length > 0
          incl_embed.each do |attr,next_attrs|
            #anything to join ?
            attr_range = klass.range(attr)
            next if attr_range.nil?
            range_objs = objects_new.select { |id,obj| obj.instance_of?(attr_range) }.values
            if range_objs.length > 0
              attr_range.where().models(range_objs).include(next_attrs).all
            end
          end
        end
         
        return models_by_id
      end

    end #queries
  end #SPARQL
end #Goo
