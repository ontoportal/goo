require 'sparql/client'
require 'sparql/client/query'

module Goo
  module SPARQL
    module Queries

      BNODES_TUPLES = Struct.new(:id,:attribute)

      def self.sparql_op_string(op)
        case op
        when :or
          return "||"
        when :and
          return "&&"
        when :==
          return "="
        end
        return op.to_s
      end

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

      def self.query_filter_sparql(klass,filter,filter_patterns,filter_graphs,
                                   filter_operations,internal_variables,inspected_patterns)
        #create a object variable to project the value in the filter
        filter.filter_tree.each do |filter_operation|
          filter_pattern_match = {}
          if filter.pattern.instance_of?(Symbol)
            filter_pattern_match[filter.pattern] = []
          else
            filter_pattern_match = filter.pattern
          end
          unless inspected_patterns.include?(filter_pattern_match)
            attr = filter_pattern_match.keys.first
            patterns_for_match(klass, attr, filter_pattern_match[attr],
                               filter_graphs, filter_patterns,
                                   [],internal_variables,
                                   subject=:id,in_union=false,in_aggregate=false)
            inspected_patterns[filter_pattern_match] = internal_variables.last
          end
          filter_var = inspected_patterns[filter_pattern_match]
          if !filter_operation.value.instance_of?(Goo::Filter)
            unless filter_operation.operator == :unbound
              filter_operations << ( 
                "?#{filter_var.to_s} #{sparql_op_string(filter_operation.operator)} " +
                " #{RDF::Literal.new(filter_operation.value).to_ntriples}")
            else
              filter_operations << "!BOUND(?#{filter_var.to_s})"
              return :optional
            end
          else
            filter_operations << "#{sparql_op_string(filter_operation.operator)}" 
            query_filter_sparql(klass,filter_operation.value,filter_patterns,
                                filter_graphs,filter_operations,
                                internal_variables,inspected_patterns)
          end
        end
      end

      def self.query_pattern(klass,attr,value=nil,subject=:id)
        value = value.id if value.class.respond_to?(:model_settings)
        if klass.attributes(:all).include?(attr) && klass.inverse?(attr)
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
          predicate = nil
          if attr.is_a?(Symbol) 
            predicate = klass.attribute_uri(attr)
          elsif attr.is_a?(RDF::URI)
            predicate = attr
          else
            raise ArgumentError, "Unknown attribute param for query `#{attr}`"
          end
          #unknown predicate
          return [klass.uri_type, [ subject , predicate , value.nil? ? attr : value]]
        end

      end

      def self.walk_pattern(klass, match_patterns, graphs, patterns, unions, 
                                internal_variables,in_aggregate=false)
        match_patterns.each do |match,in_union|
          unions << [] if in_union
          match = match.is_a?(Symbol) ? { match => [] } : match
          match.each do |attr,value|
            patterns_for_match(klass, attr, value, graphs, patterns,
                               unions,internal_variables,
                               subject=:id,in_union=in_union,in_aggregate=in_aggregate)
          end
        end
      end

      def self.patterns_for_match(klass,attr,value,graphs,patterns,unions,
                                  internal_variables,subject=:id,in_union=false,
                                  in_aggregate=false)
        if value.respond_to?(:each) || value.instance_of?(Symbol)
          next_pattern = value.instance_of?(Array) ? value.first : value

          #for filters
          next_pattern = { next_pattern => [] } if next_pattern.instance_of?(Symbol)

          value = "internal_join_var_#{internal_variables.length}".to_sym
          if in_aggregate
            value = "#{attr}_agg_#{in_aggregate}".to_sym
          end
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
                  patterns, unions, internal_variables, subject=value, 
                  in_union, in_aggregate)
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
        query_filters = options[:filters]
        aggregate = options[:aggregate]
        read_only = options[:read_only]
        graph_match = options[:graph_match]
        order_by = options[:order_by]
        collection = options[:collection]
        page = options[:page]
        count = options[:count]
        store = options[:store] || :main
        klass_struct = nil
        embed_struct = nil
        if read_only
          direct_incl = !incl ? [] : incl.select { |a| a.instance_of?(Symbol) }
          incl_embed = incl.select { |a| a.instance_of?(Hash) }.first
          klass_struct = klass.struct_object(direct_incl + (incl_embed ? incl_embed.keys : []))
          embed_struct = {}
          if incl_embed
            incl_embed.each do |k,vals|
              attrs_struct = []
              vals.each do |v|
                attrs_struct << v unless v.kind_of?(Hash)
                attrs_struct.concat(v.keys) if v.kind_of?(Hash)
              end
              embed_struct[k] = klass.range(k).struct_object(attrs_struct)
            end
          end
        end

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
            models_by_id[id] = klass_struct ? klass_struct.new : klass.new
            models_by_id[id].klass = klass if klass_struct
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
        unmapped = nil
        bnode_extraction = nil
        if incl
          if incl.first and incl.first.is_a?(Hash) and incl.first.include?:bnode
            #limitation only one level BNODE
            bnode_conf = incl.first[:bnode]
            klass_attr = bnode_conf.keys.first
            bnode_extraction=klass_attr
            bnode = RDF::Node.new
            patterns << [:id, klass.attribute_uri(klass_attr), bnode]
            bnode_conf[klass_attr].each do |in_bnode_attr|
              variables << in_bnode_attr
              patterns << [bnode, klass.attribute_uri(in_bnode_attr), in_bnode_attr]
            end
          elsif incl.first == :unmapped
            patterns << [:id, :predicate, :object]
            variables = [:id, :predicate, :object]
            unmapped = true
          else
            #make it deterministic
            incl = incl.to_a
            incl_direct = incl.select { |a| a.instance_of?(Symbol) }
            variables.concat(incl_direct)
            incl_embed = incl.select { |a| a.instance_of?(Hash) }
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
        end

        internal_variables = []
        if graph_match
          #make it deterministic - for caching
          graph_match_iteration = Goo::Base::PatternIteration.new(graph_match) 
          walk_pattern(klass,graph_match_iteration,graphs,patterns,unions,
                             internal_variables)
          graphs.uniq!
        end

        filter_id = []
        if ids
          ids.each do |id|
            filter_id << "?id = #{id.to_ntriples.to_s}"
          end
        end
        filter_id_str = filter_id.join " || "

        query_filter_str = []
        if query_filters
          filter_patterns = []
          filter_graphs = []
          inspected_patterns = {}
          query_filters.each do |query_filter|
            filter_operations = []
            type = query_filter_sparql(klass,query_filter,filter_patterns,filter_graphs,
                                                filter_operations, internal_variables,
                                                 inspected_patterns)
            query_filter_str << filter_operations.join(" ")
            graphs.concat(filter_graphs) if filter_graphs.length > 0
            if filter_patterns.length > 0
              if type == :optional
                optional_patterns.concat(filter_patterns)
              else
                patterns.concat(filter_patterns)
              end
            end
          end
        end

        aggregate_vars = nil
        aggregate_projections = nil
        if aggregate
          aggregate.each do |agg|
            agg_patterns = []
            graph_match_iteration = 
              Goo::Base::PatternIteration.new(Goo::Base::Pattern.new(agg.pattern))
            walk_pattern(klass,graph_match_iteration,graphs,agg_patterns,unions,
                             internal_variables,in_aggregate=agg.aggregate)
            if agg_patterns.length > 0
              projection = "#{internal_variables.last.to_s}_projection".to_sym
              aggregate_on_attr = internal_variables.last.to_s
              aggregate_on_attr = aggregate_on_attr[0..aggregate_on_attr.index("_agg_")-1].to_sym 
              (aggregate_projections ||={})[projection] = [agg.aggregate, aggregate_on_attr]
              (aggregate_vars ||= []) << [ internal_variables.last,
                                projection,
                               agg.aggregate ]
              variables << projection
              patterns.concat(agg_patterns)
            end
          end
        end
        order_by = nil if count
        if order_by
          order_by = order_by.first
          #simple ordering ... needs to use pattern inspection
          order_by.each do |attr,direction|
            quad = query_pattern(klass,attr,nil,:id)
            patterns << quad[1]
          end
        end

        client = Goo.sparql_query_client(store)
        variables = [:count_var] if count
        select = client.select(*variables).distinct()
        select.where(*patterns)
        optional_patterns.each do |optional|
          select.optional(*[optional])
        end
        select.union(*unions) if unions.length > 0
        if order_by
          order_by_str = order_by.map { |attr,order| "#{order.to_s.upcase}(?#{attr})" }
          select.order_by(*order_by_str)
        end

        select.filter(filter_id_str)
        select.filter("!isBLANK(?id)")
        if query_filter_str.length > 0
          query_filter_str.each do |f|
            select.filter(f)
          end
        end
        if aggregate_vars
          select.options[:group_by]=[:id]
          select.options[:count]=aggregate_vars
        end
        if count
          select.options[:count]=[[:id,:count_var,:count]]
        end
        if page
          offset = (page[:page_i]-1) * page[:page_size]
          select.slice(offset,page[:page_size])
        end
        select.from(graphs)
        select.distinct(true)

        found = Set.new
        list_attributes = Set.new(klass.attributes(:list))
        all_attributes = Set.new(klass.attributes(:all))
        objects_new = {}
        select.each_solution do |sol|
          if count
            return sol[:count_var].object
          end
          found.add(sol[:id])
          id = sol[:id]
          if bnode_extraction
            struct = klass.range(bnode_extraction).new
            variables.each do |v|
              next if v == :id
              svalue = sol[v]
              struct[v] = svalue.is_a?(RDF::Node) ? svalue : svalue.object
            end
            if list_attributes.include?(bnode_extraction)
              pre = models_by_id[sol[:id]].instance_variable_get("@#{bnode_extraction}")
              pre = pre ? (pre.dup << struct) : [struct] 
              struct = pre
            end
            models_by_id[sol[:id]].send("#{bnode_extraction}=",struct)
            next
          end
          if !models_by_id.include?(id)
            klass_model = klass_struct ? klass_struct.new : klass.new 
            klass_model.id = id
            klass_model.persistent = true unless klass_struct
            klass_model.klass = klass if klass_struct
            models_by_id[id] = klass_model
          end
          if unmapped
            models_by_id[id].unmapped_set(sol[:predicate],sol[:object])
            next
          end
          variables.each do |v|
            next if v == :id and models_by_id.include?(id)
            if (v != :id) && !all_attributes.include?(v)
              if aggregate_projections.include?(v)
                conf = aggregate_projections[v]
                models_by_id[id].add_aggregate(conf[1], conf[0], sol[v].object)
              end
              #TODO otther schemaless things
              next
            end
            #group for multiple values
            object = sol[v] ? sol[v] : nil

            #bnodes
            if object.kind_of?(RDF::Node) && object.anonymous? && incl.include?(v)
              range = klass.range(v)
              if range.respond_to?(:new)
                objects_new[object] = BNODES_TUPLES.new(id,v)
              end
              next
            end

            if object and  !(object.kind_of? RDF::URI)
              object = object.object
            end

            #dependent model creation
            if object.kind_of?(RDF::URI) && v != :id
              if objects_new.include?(object)
                object = objects_new[object]
              else
                range_for_v = klass.range(v)
                if range_for_v 
                  unless range_for_v.inmutable?
                    if !read_only
                      object = klass.range_object(v,object)
                      objects_new[object.id] = object
                    else
                      #depedent read only
                      struct = embed_struct[v].new
                      struct.id = object
                      objects_new[id] = struct
                    end
                  else
                    object = range_for_v.find(object).first
                  end
                end
              end
            end

            if object and list_attributes.include?(v)
              pre = models_by_id[id].instance_variable_get("@#{v}")
              object = !pre ? [object] : (pre.dup << object)
              object.uniq!
            end
            if klass_struct
              models_by_id[id][v] = object
            else
              models_by_id[id].send("#{v}=",object, on_load: true) if v != :id
            end
          end
        end
        return models_by_id if bnode_extraction

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

        unless read_only
          if options[:ids] #newly loaded
            models_by_id.each do |k,m|
              m.persistent=true
            end
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
              attr_range.where().models(range_objs).in(collection).include(next_attrs).all
            end
          end
        end

        #bnodes
        bnodes = objects_new.select { |id,obj| id.is_a?(RDF::Node) && id.anonymous? }
        if bnodes.length > 0
          #group by attribute
          attrs = bnodes.map { |x,y| y.attribute }.uniq
          attrs.each do |attr|
            struct = klass.range(attr)
            bnode_attrs = struct.new.to_h.keys 
            ids = bnodes.select { |x,y| y.attribute == attr }.map{ |x,y| y.id }
            klass.where.models(models_by_id.select { |x,y| ids.include?(x) }.values)
                          .in(collection)
                          .include(bnode: { attr => bnode_attrs}).all
          end
        end
         
        return models_by_id
      end

    end #queries
  end #SPARQL
end #Goo
