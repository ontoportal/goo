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

      def self.sub_property_predicates(*graphs)
        graphs = graphs.flatten!
        client = Goo.sparql_query_client(:main)
        select = client.select(:subP, :superP).distinct()
        select.where([:subP, Goo.vocabulary(:rdfs)[:subPropertyOf], :superP])
        select.from(graphs)
        tuples = []
        select.each_solution do |sol|
          tuples << [sol[:subP],sol[:superP]]
        end
        return tuples
      end

      def self.graph_predicates(*graphs)
        graphs = graphs.flatten
        client = Goo.sparql_query_client(:main)
        select = client.select(:predicate).distinct()
        select.where([:subject, :predicate, :object])
        select.from(graphs)
        predicates = []
        select.each_solution do |sol|
          predicates << sol[:predicate]
        end
        return predicates
      end

      def self.model_exist(model,id=nil,store=:main)
        id = id || model.id
        so = Goo.sparql_query_client(store).ask.from(model.graph).
          whether([id, RDF.type, model.class.uri_type(model.collection)])
        return so.true?
      end

      def self.query_filter_sparql(klass,filter,filter_patterns,filter_graphs,
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
                                   [],internal_variables,
                                   subject=:id,in_union=false,in_aggregate=false,
                                   collection=collection)
            inspected_patterns[filter_pattern_match] = internal_variables.last
          end
          filter_var = inspected_patterns[filter_pattern_match]
          if !filter_operation.value.instance_of?(Goo::Filter)
            case filter_operation.operator
            when  :unbound
              filter_operations << "!BOUND(?#{filter_var.to_s})"
              return :optional

            when :bound
              filter_operations << "BOUND(?#{filter_var.to_s})"
              return :optional
            when :regex
              if  filter_operation.value.is_a?(String)
                filter_operations << "REGEX(?#{filter_var.to_s} , \"#{filter_operation.value.to_s}\")"
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
            query_filter_sparql(klass,filter_operation.value,filter_patterns,
                                filter_graphs,filter_operations,
                                internal_variables,inspected_patterns,collection)
          end
        end
      end

      def self.model_load(*options)
        Goo::SPARQL::Loader.model_load(*options)
      end


      end #Queries
    end #SPARQL
end #Goo
