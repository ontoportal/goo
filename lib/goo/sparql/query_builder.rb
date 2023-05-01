module Goo
  module SPARQL
    class QueryBuilder
      include Goo::SPARQL::QueryPatterns

      def initialize(options)
        @no_graphs = options[:no_graphs]
        @query_filters = options[:filters]
        @klass = options[:klass]
        @store = options[:store] || :main
        @page = options[:page]
        @count = options[:count]
        @graph_match = options[:graph_match]
        @unions = options[:unions] || []
        @aggregate = options[:aggregate]
        @collection = options[:collection]
        @model_query_options = options[:query_options]
        @enable_rules = options[:rules]
        @order_by = options[:order_by]
        @internal_variables_map = {}
        @query = get_client
      end

      def build_select_query(ids, variables, graphs, patterns,
                             query_options, properties_to_include)

        patterns = graph_match(@collection, @graph_match, graphs, @klass, patterns, query_options, @unions)

        aggregate_projections, aggregate_vars,
          variables, optional_patterns = get_aggregate_vars(@aggregate, @collection, graphs,
                                                            @klass, @unions, variables)

        @order_by, variables, optional_patterns = init_order_by(@count, @klass, @order_by, optional_patterns, variables,patterns, query_options, graphs)
        variables, patterns = add_some_type_to_id(patterns, query_options, variables)

        query_filter_str, patterns, optional_patterns, filter_variables =
          filter_query_strings(@collection, graphs, @klass, optional_patterns, patterns, @query_filters)

        variables = [] if @count
        variables.delete :some_type

        select_distinct(variables, aggregate_projections, filter_variables)
          .from(graphs)
          .where(patterns)
          .union_bind_in_where(properties_to_include)

        optional_patterns.each do |optional|
          @query.optional(*[optional])
        end

        query_filter_str&.each do |filter|
          @query.filter(filter)
        end

        @query.union(*@unions) unless @unions.empty?

        ids_filter(ids) if ids
        order_by if @order_by

        put_query_aggregate_vars(aggregate_vars) if aggregate_vars
        count if @count
        paginate if @page

        ## TODO see usage of rules and query_options
        query_options.merge!(@model_query_options) if @model_query_options
        query_options[:rules] = [:NONE] unless @enable_rules
        query_options = nil if query_options.empty?
        if query_options
          query_options[:rules] = query_options[:rules]&.map { |x| x.to_s }.join('+')
        else
          query_options = { rules: ['NONE'] }
        end
        @query.options[:query_options] = query_options
        [@query, aggregate_projections]
      end

      def union_bind_in_where(properties)
        binding_as = []
        properties.each do |property_attr, property|
          predicates = [property[:uri]] + (property[:equivalents] || [])
          options = {
            binds: [{ value: property_attr, as: :attributeProperty }]
          }
          subject = property[:subject] || :id
          predicates.uniq.each do |predicate_uri|
            pattern = if property[:is_inverse]
                        [:attributeObject, predicate_uri, subject]
                      else
                        [subject, predicate_uri, :attributeObject]
                      end
            binding_as << [[pattern], options]
          end
        end
        @query.optional_union_with_bind_as(*binding_as) unless binding_as.empty?
        self
      end

      def where(patterns)
        @query.where(*patterns)
        self
      end

      def paginate
        offset = (@page[:page_i] - 1) * @page[:page_size]
        @query.slice(offset, @page[:page_size])
        self
      end

      def count
        @query.options[:count] = [%i[id count_var count]]
        self
      end

      def put_query_aggregate_vars(aggregate_vars)
        @query.options[:group_by] = [:id]
        @query.options[:count] = aggregate_vars
        self
      end

      def order_by
        order_by_str = @order_by.map do |attr, order|
          if order.is_a?(Hash)
            sub_attr, order = order.first
            attr = @internal_variables_map[sub_attr]
          end
          "#{order.to_s.upcase}(?#{attr})"
        end
        @query.order_by(*order_by_str)
        self
      end

      def from(graphs)

        graphs.select! { |g| g.to_s['owl#Class'].nil? } if !graphs.nil? && !graphs.empty?

        if @no_graphs
          @query.options[:graphs] = graphs.uniq
        else
          @query.from(graphs.uniq)
        end
        self
      end

      def select_distinct(variables, aggregate_projections, filter_variables)
        select_vars = variables.dup
        reject_aggregations_from_vars(select_vars, aggregate_projections) if aggregate_projections
        select_vars = (select_vars + filter_variables).uniq  if @page # Fix for 4store pagination with a filter
        @query = @query.select(*select_vars).distinct(true)
        self
      end

      def ids_filter(ids)
        filter_id = []

        ids.each do |id|
          filter_id << "?id = #{id.to_ntriples.to_s.gsub(' ', '%20')}"
        end
        filter_id_str = filter_id.join ' || '
        @query.filter filter_id_str
        self
      end

      private

      def patterns_for_match(klass, attr, value, graphs, patterns, unions,
                             internal_variables, subject = :id, in_union = false,
                             in_aggregate = false, query_options = {}, collection = nil)
        if value.respond_to?(:each) || value.instance_of?(Symbol)
          next_pattern = value.instance_of?(Array) ? value.first : value

          #for filters
          next_pattern = { next_pattern => [] } if next_pattern.instance_of?(Symbol)

          value = "internal_join_var_#{internal_variables.length}".to_sym
          if in_aggregate
            value = "#{attr}_agg_#{in_aggregate}".to_sym
          end
          internal_variables << value
          @internal_variables_map[attr] = value
        end

        add_rules(attr, klass, query_options)
        graph, pattern =
          query_pattern(klass, attr, value: value, subject: subject, collection: collection)
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
          next_pattern.each do |next_attr, next_value|
            patterns_for_match(range, next_attr, next_value, graphs,
                               patterns, unions, internal_variables, subject = value,
                               in_union, in_aggregate, collection = collection)
          end
        end
      end

      def walk_pattern(klass, match_patterns, graphs, patterns, unions,
                       internal_variables, in_aggregate = false, query_options = {},
                       collection)
        match_patterns.each do |match, in_union|
          unions << [] if in_union
          match = match.is_a?(Symbol) ? { match => [] } : match
          match.each do |attr, value|
            patterns_for_match(klass, attr, value, graphs, patterns,
                               unions, internal_variables,
                               subject = :id, in_union = in_union,
                               in_aggregate = in_aggregate,
                               query_options = query_options,
                               collection)
          end
        end
      end

      def get_aggregate_vars(aggregate, collection, graphs, klass, unions, variables)
        # mdorf, 6/03/20 If aggregate projections (sub-SELECT within main SELECT) use an alias, that alias cannot appear in the main SELECT
        # https://github.com/ncbo/goo/issues/106
        # See last sentence in https://www.w3.org/TR/sparql11-query/#aggregateExample
        aggregate_vars = nil
        aggregate_projections = nil
        optional_patterns = []

        aggregate&.each do |agg|
          agg_patterns = []
          graph_match_iteration =
            Goo::Base::PatternIteration.new(Goo::Base::Pattern.new(agg.pattern))
          walk_pattern(klass, graph_match_iteration, graphs, agg_patterns, unions,
                       internal_variables, in_aggregate = agg.aggregate, collection)
          unless agg_patterns.empty?
            projection = "#{internal_variables.last.to_s}_projection".to_sym
            aggregate_on_attr = internal_variables.last.to_s
            aggregate_on_attr =
              aggregate_on_attr[0..aggregate_on_attr.index('_agg_') - 1].to_sym
            (aggregate_projections ||= {})[projection] = [agg.aggregate, aggregate_on_attr]
            (aggregate_vars ||= []) << [internal_variables.last,
                                        projection,
                                        agg.aggregate]
            variables << projection
            optional_patterns.concat(agg_patterns)
          end
        end
        [aggregate_projections, aggregate_vars, variables, optional_patterns]
      end

      def graph_match(collection, graph_match, graphs, klass, patterns, query_options, unions)
        if graph_match
          #make it deterministic - for caching
          graph_match_iteration = Goo::Base::PatternIteration.new(graph_match)
          walk_pattern(klass, graph_match_iteration, graphs, patterns, unions,
                       internal_variables, in_aggregate = false, query_options, collection)
          graphs.uniq!
        end
        patterns
      end

      def get_client
        Goo.sparql_query_client(@store)
      end

      def init_order_by(count, klass, order_by, optional_patterns, variables, patterns, query_options, graphs)
        order_by = nil if count
        if order_by
          order_by = order_by.first
          #simple ordering ... needs to use pattern inspection
          order_by.each do |attr, direction|

            if direction.is_a?(Hash)
              sub_attr, direction = direction.first
              graph_match_iteration = Goo::Base::PatternIteration.new(Goo::Base::Pattern.new({attr => [sub_attr]}))
              old_internal = internal_variables.dup
              walk_pattern(klass, graph_match_iteration, graphs, optional_patterns, @unions, internal_variables, in_aggregate = false, query_options, @collection)
              variables << (internal_variables - old_internal).last
            else
              quad = query_pattern(klass, attr)
              optional_patterns << quad[1]
              variables << attr
            end

            #patterns << quad[1]
            #mdorf, 9/22/16 If an ORDER BY clause exists, the columns used in the ORDER BY should be present in the SPARQL select
            #variables << attr unless variables.include?(attr)
          end
        end
        [order_by, variables, optional_patterns, patterns]
      end

      def sparql_op_string(op)
        case op
        when :or
          return '||'
        when :and
          return '&&'
        when :==
          return '='
        end
        op.to_s
      end

      def query_filter_sparql(klass, filter, filter_patterns, filter_graphs,
                              filter_operations,
                              internal_variables,
                              inspected_patterns,
                              collection)
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
                               [], internal_variables,
                               subject = :id, in_union = false, in_aggregate = false,
                               collection = collection)
            inspected_patterns[filter_pattern_match] = internal_variables.last
          end
          filter_var = inspected_patterns[filter_pattern_match]

          unless filter_operation.value.instance_of?(Goo::Filter)
            case filter_operation.operator
            when  :unbound
              filter_operations << "!BOUND(?#{filter_var.to_s})"
              return :optional

            when :bound
              filter_operations << "BOUND(?#{filter_var.to_s})"
              return :optional
            when :regex
              if  filter_operation.value.is_a?(String)
                filter_operations << "REGEX(STR(?#{filter_var.to_s}) , \"#{filter_operation.value.to_s}\", \"i\")"
              end

            else
              value = RDF::Literal.new(filter_operation.value)
              if filter_operation.value.is_a? String
                value = RDF::Literal.new(filter_operation.value, :datatype => RDF::XSD.string)
              end
              filter_operations << (
                "?#{filter_var.to_s} #{sparql_op_string(filter_operation.operator)} " +
                  " #{value.to_ntriples}")
            end

          else
            filter_operations << "#{sparql_op_string(filter_operation.operator)}"
            query_filter_sparql(klass, filter_operation.value, filter_patterns,
                                filter_graphs, filter_operations,
                                internal_variables, inspected_patterns, collection)
          end
        end
      end

      def filter_query_strings(collection, graphs, klass,
                               optional_patterns, patterns,
                               query_filters)
        query_filter_str = []
        filter_graphs = []
        filter_variables = []
        inspected_patterns = {}
        query_filters&.each do |query_filter|
          filter_operations = []
          filter_patterns = []
          type = query_filter_sparql(klass, query_filter, filter_patterns, filter_graphs,
                                     filter_operations, internal_variables,
                                     inspected_patterns, collection)
          query_filter_str << filter_operations.join(' ')
          graphs.concat(filter_graphs) unless filter_graphs.empty?
          unless filter_patterns.empty?
            if type == :optional
              optional_patterns.concat(filter_patterns)
            else
              patterns.concat(filter_patterns)
            end
          end
          filter_variables << inspected_patterns.values.last
        end
        [query_filter_str, patterns, optional_patterns, filter_variables]
      end

      def reject_aggregations_from_vars(variables, aggregate_projections)
        variables.reject! { |var| aggregate_projections.key?(var) }
      end

      def add_some_type_to_id(patterns, query_options, variables)
        #rdf:type <x> breaks the reasoner
        if query_options && !query_options.empty? && query_options[:rules] != [:NONE]
          patterns[0] = [:id, RDF[:type], :some_type]
          variables << :some_type
        end
        [variables, patterns]
      end

      def internal_variables
        @internal_variables_map.values
      end
    end
  end
end

