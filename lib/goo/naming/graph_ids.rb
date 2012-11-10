
module Goo
  module Naming 
    class PolicyNotSupported < StandardError
    end
    class InvalidGraphId < StandardError
    end

    def self.getGraphId(model)
      policy = model.class.goop_settings[:graph_policy] 
      #TODO: this can be improved to discover new policies based on the symbol.
      #      good enough for now
      if policy == :type_id_graph_policy
        graph_id = TypeIdGraphPolicy.getGraphId(model)
        raise InvalidGraphId, "#{graph_id} does not parse as URI. Check the graph generator." \
          unless SparqlRd::Utils::Http.valid_uri? graph_id 
        return graph_id
      end
      #TODO implement other policies
      raise PolicyNotSupported, "Policy '#{policy}' not supported"
    end

    class TypeIdGraphPolicy
      def self.getGraphId(model)
        vocabs = Goo::Naming.get_vocabularies 
        reg = vocabs.get_model_registry(model.class)
        prefix = vocabs.get_prefix reg[:prefix] 
        if reg[:prefix] == :default
          graph_id = prefix + model.class.to_s.camelize 
        else
          graph_id = prefix + reg[:type].to_s.camelize
        end
        return graph_id
      end
    end
  end
end
