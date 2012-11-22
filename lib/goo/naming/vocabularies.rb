
module Goo 
  module Naming
    @@_vocabularies = nil
    @@lock = Mutex.new

    class StatusException < StandardError
    end
    class PrefixVocabularieNotFound < StandardError
    end
    class PropertyNameNotFound < StandardError
    end
    class ModelNotFound < StandardError
    end

    def self.register_vocabularies(vocabularies)
      @@lock.synchronize do
        #TODO: better to enforce this lock outside.
        #TODO: probably better to do single threaded and run it JUST on startup.
        raise StatusException, "Only one vocabulary can be registered" \
          unless @@_vocabularies == nil
        @@_vocabularies = vocabularies
      end
    end

    def self.get_vocabularies
      raise StatusException, "No vocabularies established in Goo framework." \
        if @@_vocabularies == nil
      @@_vocabularies
    end

    class Vocabularies
      
      attr_accessor :default

      def initialize()
        #TODO: bad naming - confusing ... change!
        @_vocabs = {}
        @_inverse_vocabs = {}
        @_properties = {}


        #TODO: models ?
        @_types = {}
      end

      def default= default_prefix
        @default = default_prefix
        register(:default,@default)
        register_model(:default, :default, :default)
      end
      def get_prefix(p)
        return @_vocabs[p] if @_vocabs[p] != nil
        raise PrefixVocabularieNotFound, "Prefix '#{p}' not in vocabularies"
      end

      def construct_uri(namespace, name, predicate)
        fragment = name.to_s.camelize
        fragment[0] = fragment[0].downcase if predicate
        namespace + fragment
      end

      def uri_for_predicate(name,model_class)
        if not @default
          raise PropertyNameNotFound, "Property name #{name} not found in vocabularies" \
            unless @_properties[name]
        end
        prefix = @_properties[name] || :default 
        namespace = @_vocabs[prefix]
        return construct_uri(namespace, name, true)
      end

      def find_prefix_for_uri(uri)
        @_inverse_vocabs.each_pair do |prefix,reg|
          return reg if uri.start_with? prefix
        end
        return nil
      end

      def attr_for_predicate_uri(uri, model_class)
        return :rdf_type if RDF.rdf_type? uri
        prefix = find_prefix_for_uri(uri)      
        return nil unless prefix
        fragment = uri[@_vocabs[prefix].length, uri.length]
        #round trip to safely know that the property is in reg
        fragment_symbol=fragment.underscore.to_sym
        if @_properties[fragment_symbol] == prefix or \
             prefix == :default
          return fragment_symbol
        end
        return nil
      end

      def uri_for_type(model_class)
        model = model_class.goop_settings[:model]
        if not @default
          raise ModelNotFound, "Model  #{model} not found in vocabularies" \
            unless @_types[model]
        end 
        if @_types[model]
          prefix = @_types[model][:prefix]
        else 
          prefix = :default
        end
        return construct_uri(@_vocabs[prefix], model, false)
      end

      def register(prefix,namespace, properties = [])
        raise ArgumentError, "Prefix and/or namespace can only be registered once" \
          if @_vocabs[prefix] or @_inverse_vocabs[namespace]
        @_vocabs[prefix] = namespace
        return if prefix == :unknown
        @_inverse_vocabs[namespace]=prefix
        add_properties_to_prefix(prefix,properties)
      end

      def add_properties_to_prefix(prefix, properties)
        properties.each do |prop|
          raise ArgumentError, "Property #{prop} already registered for prefix #{@_properties[prop]}" \
            if @_properties[prop]
          @_properties[prop] = prefix
        end
      end

      def register_model(prefix, type, model_class)
        raise ArgumentError, "Type #{type} already registered for prefix #{@_types[type]}" \
          if @_types[type]
        @_types[type] = { :prefix => prefix, :model_class => model_class, :type => type} 
      end

      def is_model_registered(model_class)
        (get_model_registry model_class)[:model_class] != nil
      end

      def get_model_registry(model_class)
        @_types.each_pair do |k,v|
          return v if model_class == v[:model_class]
        end
        @_types[:default]
      end

      def is_type_registered?(type)
        return @_types.include? type.to_sym
      end

      def get_ns_by_prefix(prefix)
        @_vocabs[prefix]
      end

      def get_model_class_for(model_type)
        if @_types.include? model_type.to_sym
          return @_types[model_type.to_sym][:model_class]
        end
        return nil
      end
      
    end
  end
end
