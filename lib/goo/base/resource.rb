require 'cgi'
require_relative "settings/settings"

module Goo
  module Base

    class Resource
      include Goo::Base::Settings
      #include Goo::Search

      attr_reader :loaded_attributes
      attr_reader :modified_attributes
      attr_reader :errors

      attr_reader :id

      def initialize(*args)
        @loaded_attributes = Set.new
        @modified_attributes = Set.new
        @previous_values = nil
        @persistent = false

        attributes = args[0] || {}
        opt_symbols = Goo.resource_options
        attributes.each do |attr,value|
          next if opt_symbols.include?(attr)
          self.send("#{attr}=",value)
        end

        @id = nil
      end

      def valid?
        validation_errors = {}
        self.class.attributes.each do |attr|
          inst_value = self.instance_variable_get("@#{attr}")
          attr_errors = Goo::Validators::Enforce.enforce(self,attr,inst_value)
          unless attr_errors.nil?
            validation_errors[attr] = attr_errors
          end
        end

        unless @persistent
          uattr = self.class.name_with.instance_of?(Symbol) ? self.class.name_with : :proc_naming
          if validation_errors[uattr].nil?
            begin
              if self.exist?(from_valid=true)
                validation_errors[uattr] = validation_errors[uattr] || {}
                validation_errors[uattr][:duplicate] =
                  "There is already a persistent resource with id `#{@id.to_s}`"
              end
            rescue ArgumentError => e
              validation_errors[uattr][:unique] = e.message
            end 
          end
        end

        @errors = validation_errors.freeze
        return @errors.length == 0
      end

      def id=(new_id)
        if !@id.nil? and @persistent
          raise ArgumentError, "The id of a persistent object cannot be changed."
        end
        raise ArgumentError, "ID must be an RDF::URI" unless new_id.kind_of?(RDF::URI)
        @id = new_id
      end

      def id
        if @id.nil?
          custom_name = self.class.name_with
          if custom_name.instance_of?(Symbol)
            @id = id_from_attribute()
          elsif custom_name
            @id = custom_name.call(self)
          else
            raise RuntimeError, "custom_name is nil. settings for this model are incorrect."
          end
        end
        return @id
      end

      def persistent?
        return @persistent
      end

      def persistent=(val)
        @persistent=val
      end

      def modified?
        return modified_attributes.length > 0
      end

      def exist?(from_valid=false)
        _id = @id
        if _id.nil? and !from_valid
          _id = id_from_attribute()
        end
        return Goo::SPARQL::Queries.model_exist(self,id=_id)
      end

      def fully_loaded?
        #every declared attributed has been loaded
        return @loaded_attributes == Set.new(self.class.attributes)
      end

      def missing_load_attributes
        #every declared attributed has been loaded
        return Set.new(self.class.attributes) - @loaded_attributes
      end

      def delete
        raise ArgumentError, "This object is not persistent and cannot be deleted" if !@persistent

        if !fully_loaded?
          missing = missing_load_attributes
          options_load = { models: [ self ], klass: self.class, :include => missing }
          if self.class.collection_opts
            options_load[:collection] = self.collection 
          end
          Goo::SPARQL::Queries.model_load(options_load)
        end

        graph_delete = Goo::SPARQL::Triples.model_delete_triples(self)

        begin
          Goo.sparql_update_client.delete_data(graph_delete, graph: self.graph)
        rescue Exception => e
          binding.pry
        end
        @persistent = false
        @modified = true
        return nil
      end

      def graph
        opts = self.class.collection_opts
        if opts.nil?
          return self.class.uri_type
        end
        col = collection
        return col ? col.id : nil
      end

      def collection
        opts = self.class.collection_opts
        if opts.instance_of?(Symbol)
          if self.class.attributes.include?(opts)
            value = self.send("#{opts}")
            if value.nil?
              raise ArgumentError, "Collection `#{opts}` is nil"
            end
            return value
          else
            raise ArgumentError, "Collection `#{opts}` is not an attribute"
          end
        else
          binding.pry
        end
      end

      def save
        raise ArgumentError, "Object is not modified" unless modified?
        raise Goo::Base::NotValidException, "Object is not valid. Check errors." unless valid?

        graph_insert, graph_delete = Goo::SPARQL::Triples.model_update_triples(self)
        graph = self.graph() 
        if graph_delete and graph_delete.size > 0
          begin
            Goo.sparql_update_client.delete_data(graph_delete, graph: graph)
          rescue Exception => e
            binding.pry
          end
        end
        if graph_insert and graph_insert.size > 0
          begin
            Goo.sparql_update_client.insert_data(graph_insert, graph: graph)
          rescue Exception => e
            binding.pry
          end
        end

        #after save all attributes where loaded
        @loaded_attributes = Set.new(self.class.attributes)

        @modified_attributes = Set.new
        @persistent = true
        return self
      end

      def previous_values
        return @previous_values
      end


      ###
      # Class level methods
      # ##
      def self.find(id, *options)
        unless id.instance_of?(RDF::URI)
          id = id_from_unique_attribute(name_with(),id)
        end
        options_load = { ids: [id], klass: self }.merge(options[-1] || {})
        if !self.collection_opts.nil? and !options_load.include?(:collection)
          raise ArgumentError, "Collection needed call `#{self.name}.find`"
        end
        models_by_id = Goo::SPARQL::Queries.model_load(options_load)
        return models_by_id[id]
      end

      def self.all(*options)
        options = options.first || {}
        unless options.length == 0 || (options.length == 1 && options[:include])
          raise ArgumentError, ".all only accepts the include options" 
        end
        return self.where(options)
      end

      def self.where(*options)
        filters = options.first || {}
        # ? a pattern right away and nothing else
        if filters.kind_of?(Goo::Base::Pattern)      
          filters = { :pattern => filters }
          if options.length > 1 && options.last.instance_of?(Hash)
            filters.merge!(options.last)
          end
        end
        incl = filters.delete(:include) || []
        models = filters.delete(:models) || []

        options_load = { models: models, include: incl, filters: filters, klass: self }
        models_by_id = Goo::SPARQL::Queries.model_load(options_load)
        return models_by_id.values
      end

      protected
      def id_from_attribute()
          uattr = self.class.name_with
          uvalue = self.send("#{uattr}")
          return self.class.id_from_unique_attribute(uattr,uvalue)
      end

    end

  end
end
