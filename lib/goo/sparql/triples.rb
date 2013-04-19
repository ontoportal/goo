module Goo
  module SPARQL
    module Triples

      def self.model_delete_triples(model)
        subject = model.id
        graph_delete = nil
        graph_delete = RDF::Graph.new
        graph_delete << [subject, RDF.type, model.class.uri_type]
        model.class.attributes.each do |attr|
          next if model.class.collection?(attr)
          predicate = model.class.attribute_uri(attr)
          value = model.send("#{attr}")
          values = value.kind_of?(Array) ? value : [value]
          values.each do |v|
            object = v.class.respond_to?(:shape_attribute) ? v.id : v
            next if object.nil?
            graph_delete << [subject, predicate, object]
          end
        end
        return graph_delete
      end

      def self.model_update_triples(model)
        subject = model.id

        graph_delete = nil
        if model.previous_values
          graph_delete = RDF::Graph.new
          model.previous_values.each do |attr,value|
            predicate = model.class.attribute_uri(attr)
            values = value.kind_of?(Array) ? value : [value]
            values.each do |v|
              object = v.class.respond_to?(:shape_attribute) ? v.id : v
              next if object.nil?
              graph_delete << [subject, predicate, object]
            end
          end
        end
          
        graph_insert = RDF::Graph.new
        unless model.persistent?
          graph_insert << [subject, RDF.type, model.class.uri_type]
        end
        #set default values before saving
        if not model.persistent?
          model.class.attributes_with_defaults.each do |attr|
            value = model.send("#{attr}")
            if value.nil?
              value = model.class.default(attr).call(model)
              model.send("#{attr}=",value)
            end
          end
        end

        model.modified_attributes.each do |attr|
          next if model.class.collection?(attr)
          predicate = model.class.attribute_uri(attr)
          value = model.send("#{attr}")
          next if value.nil?
          values = value.kind_of?(Array) ? value : [value]
          values.each do |v|
            object = v.class.respond_to?(:shape_attribute) ? v.id : v
            graph_insert << [subject, predicate, object]
          end
        end
        return [graph_insert, graph_delete]

      end #model_update_triples

    end
  end
end

