module Goo
  module Base
    module Settings
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        attr_accessor :model_settings
        attr_reader :model_name
        attr_reader :attribute_uris

        def default_model_options
          return {}
        end

        def model(*args)

          if args.length == 0
            binding.pry
          end

          model_name = args[0]
          @model_name = model_name.to_sym
          
          #a hash with options is expected
          options = args[1]

          @model_settings = default_model_options.merge(options || {})

          Goo.add_model(@model_name,self)
          @attribute_uris = {}
          @namespace = Goo.vocabulary(@model_settings[:namespace])
          @uri_type = @namespace[@model_name.to_s.camelize]
          @model_settings[:range] = {}
        end

        def attributes(*options)
          if options and options.length > 0
            filt = options.first 
            return (@model_settings[:attributes].select{ |attr,opts| opts[:enforce].include?(filt) }).keys()
          end
          return @model_settings[:attributes].keys
        end

        def attributes_with_defaults
          return (@model_settings[:attributes].select{ |attr,opts| opts[:default] }).keys()
        end

        def default(attr)
          return @model_settings[:attributes][attr][:default]
        end

        def attribute_namespace(attr)
          return @model_settings[:attributes][attr][:namespace]
        end

        def range(attr)
          @model_settings[:range][attr]
        end

        def attribute(*args)
          options = args.reverse
          attr_name = options.pop
          attr_name = attr_name.to_sym
          options = options.pop
          unless @model_settings.include? :attributes
            @model_settings[:attributes] = {}
          end
          if options[:enforce].nil? or !options[:enforce].include?(:list)
            options[:enforce] = options[:enforce] ? (options[:enforce] << :no_list) : [:no_list]
          end
          @model_settings[:attributes][attr_name] = options
          shape_attribute(attr_name)
          namespace = attribute_namespace(attr_name)
          vocab = Goo.vocabulary(namespace) #returns default for nil input
          @attribute_uris[attr_name] = vocab[attr_name]
          if options[:enforce].include? :unique
            unless @unique_attribute.nil?
              raise ArgumentError, "Model `#{@model_name}` has two or more unique attributes."
            end
            @unique_attribute = attr_name
          end

          @model_settings[:attributes][attr_name][:enforce].each do |opt|
            if Goo.models.include?(opt) || opt.kind_of?(Goo::Base::Resource)
              opt = Goo.models[opt] if opt.instance_of?(Symbol)
              @model_settings[:range][attr_name]=opt
              break
            end
          end
        end
   
        def attribute_uri(attr)
          return @attribute_uris[attr]
        end

        def shape_attribute(attr)
          return if attr == :resource_id
          attr = attr.to_sym
          define_method("#{attr}=") do |*args|
            @loaded_attributes.add(attr)
            value = args[0]
            unless args.last.instance_of?(Hash) and args.last[:on_load]
              prev = self.instance_variable_get("@#{attr}")
              if !prev.nil? and !@modified_attributes.include?(attr)
                if prev != value 
                  @previous_values = @previous_values || {}
                  @previous_values[attr] = prev 
                end
              end
              @modified_attributes.add(attr)
            end
            if value.instance_of?(Array)
              value = value.dup.freeze
            end
            self.instance_variable_set("@#{attr}",value)
          end
          define_method("#{attr}") do |*args|
            if (not @persistent) or @loaded_attributes.include?(attr)
              return self.instance_variable_get("@#{attr}")
            else
              raise Goo::Base::AttributeNotLoaded, "Persistent object with `#{attr}` not loaded"
            end
          end
        end
        def uri_type
          return @uri_type
        end
        def namespace
          return @namespace
        end
        def unique_attribute
          return @unique_attribute
        end

        def id_from_unique_attribute(attr,value_attr)
          if value_attr.nil?
            raise ArgumentError, "`#{attr}` value is nil. Id for resource cannot be generated."
          end
          uri_last_fragment = CGI.escape(value_attr)
          return namespace[model_name.to_s + '/' + uri_last_fragment]
        end

        def name_with
          return @model_settings[:name_with]
        end
      end
    end
  end
end
