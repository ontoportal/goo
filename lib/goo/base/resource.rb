require_relative "settings/settings"
require_relative "../utils/rdf"

module Goo
  module Base

    class Resource < OpenStruct
      include Goo::Base::Settings

      attr_reader :attributes
      attr_reader :inverse_atttributes
      attr_reader :errors

      def initialize(attributes = {})
        model = self.class.goop_settings[:model]
        raise ArgumentError, "Can't create model, model settings do not contain model type." \
          unless model != nil
        raise ArgumentError, "Can't create model, model settings do not contain graph policy." \
          unless self.class.goop_settings[:graph_policy] != nil
        super()

        @attributes = attributes.dup
        @attributes[:internals] = Internals.new(self)
        @attributes[:internals].new_resource

        @_cached_exist = nil
        shape_me

        #anon objects have an uuid property
        policy = self.class.goop_settings[:unique][:generator]
        if policy == :anonymous
          if !self.respond_to? :uuid
            shape_attribute :uuid
          end
          if not @table.include? :uuid
            self.uuid = Goo.uuid.generate
          end
        end
      end

      def self.inherited(subclass)
        #hook to set up default configuration.
        subclass.model
      end

      def contains_data?
        ((@attributes.has_key? :internals) and @attributes.length > 1) or
          ((not @attributes.has_key? :internals) and @attributes.length > 0)
      end

      def internals()
        @attributes[:internals]
      end

      def shape_attribute(attr)
        return if attr == :resource_id
        attr = attr.to_sym
        validators = self.class.attribute_validators(attr)
        cardinality_opt = validators[:cardinality]
        card_validator = nil
        if cardinality_opt
          card_validator = Goo::Validators::CardinalityValidator.new(cardinality_opt)
        end
        prx = AttributeValueProxy.new(card_validator,
                                      @attributes[:internals])
        define_singleton_method("#{attr}=") do |*args|
          in_load = false
          if args[-1].kind_of? Hash
            in_load = args[-1].include? :in_load
            args = args[0,args.length-1]
          end
          if self.class.goop_settings[:collection] and\
             self.class.goop_settings[:collection][:attribute] == attr
            if args.length > 1
              raise ArgumentError, "#{attr} is a collection value and must have a single value"
            end
            value = args[0]
            self.internals.collection = value
          end
          if !in_load and internals.lazy_loaded? and !(internals.loaded_attrs.include? attr.to_sym)
            raise NotLoadedResourceError,
              "Object has been lazy loaded. Call `load` to access/write attributes"
          end
          if self.class.inverse_attr?(attr)
            raise ArgumentError, "#{attr} is defined as inverse property and cannot be set."
          end
          current_value = @table[attr]
          value = args.flatten
          if value and !value.instance_of? SparqlRd::Resultset::Literal
            if !value.respond_to? :goop_settings
              value.map! do |v|
                if v.nil?
                  nil
                else
                  if v.kind_of? Resource
                    v
                  else
                    SparqlRd::Resultset.get_literal_from_object(v)
                  end
                end
              end
            end
          end
          tvalue = prx.call({ :value => value, :attr => attr,
                              :current_value => current_value })
          if attr == :uuid
            #uuid forced to be unique
            tvalue = tvalue[0]
          end
          if internals.persistent?
            if not internals.lazy_loaded? and
               not in_load and
               self.class.goop_settings[:unique] and
               self.class.goop_settings[:unique][:fields] and
               self.class.goop_settings[:unique][:fields].include? attr
               unless value[0] == self.send("#{attr}")
                 raise KeyFieldUpdateError,
                   "Attribute '#{attr}' cannot be changed in a persisted object."
               end
            end
          end
          if !in_load
            if attr != :uuid and @table[attr]
              internals.modified = internals.modified || (@table[attr] != tvalue)
            elsif attr != :uuid
              internals.modified = true
            end
          end
          @table[attr] = tvalue
        end
        define_singleton_method("#{attr}") do |*args|
          attr_cpy = attr
          if self.class.goop_settings[:collection] and\
             self.class.goop_settings[:collection][:attribute] == attr_cpy
            return self.internals.collection
          end

          origin_attr = attr_cpy
          use_as_attr = self.class.use_as attr_cpy
          attr_cpy = use_as_attr unless use_as_attr.nil?

          if (not self.class.inverse_attr? attr_cpy) and
            internals.lazy_loaded? and (!internals.loaded_attrs.include?(attr_cpy.to_sym) or use_as_attr)
            return load_on_demand([attr_cpy], use_as_attr.nil? ? nil : [origin_attr])
          end

          if self.class.inverse_attr? attr_cpy
            query_options = self.class.attr_query_options(origin_attr)
            inv_cls, inv_attr = self.class.inverse_attr_options(attr_cpy)
            where_opts = { inv_attr => self, ignore_inverse: true }
            if inv_cls.goop_settings[:collection]
              #assume same collection
              where_opts[inv_cls.goop_settings[:collection][:attribute]] = self.internals.collection
            end
            where_opts[:query_options] = query_options unless query_options.nil?
            values = inv_cls.where(where_opts)
            return values.dup
          end

          attr_value = @table[origin_attr]
          #returning default value
          if attr_value.nil?
            return nil unless self.persistent?
            attrs = self.class.goop_settings[:attributes]
            if attrs.include? attr_cpy
              if attrs[attr_cpy].include? :default
                default_value = attrs[attr_cpy][:default].call(self)
                @table[attr_cpy] = default_value
                return default_value
              end
            end
          end

          return attr_value
        end
      end

      def shape_me
        check_rdftype_inconsistency

        #set to nil all the known properties via validators
        keys_attr = @attributes.keys
        self.class.attributes.each do |att_name, options|
          keys_attr << att_name
        end
        keys_attr.each do |attr|
          next if attr == :internals
          shape_attribute(attr)
        end

        #if attributes are set then set values for properties.
        @attributes.each_pair do |attr,value|
          next if attr == :internals
          self.send("#{attr}=", *value, :in_load => true)
        end
        internal_status = @attributes[:internals]
        @table[:internals] = internal_status
        @attributes = @table
      end

      def method_missing(sym, *args, &block)
        raise NoMethodError, "This Resource is defined as not schemaless. Object cannot respond to `#{sym}`" if !self.class.goop_settings[:schemaless]
        if sym.to_s[-1] == "="
          shape_attribute(sym.to_s.chomp "=")
          return self.send(sym,args)
        end
        return nil
      end

      #set resource id wihout loading the rest of the attributes.
      def resource_id=(resource_id)
        internals.id=resource_id
      end

      def resource_id()
        internals.id
      end

      def exist?(reload=false)
        if @_cached_exist.nil? or reload
          epr = Goo.store(@store_name)
          return false if resource_id.bnode? and (not resource_id.skolem?)
          q = Queries.get_exist_query(self)
          rs = epr.query(q)
          @_cached_exist = false
          rs.each_solution do |sol|
            @_cached_exist = true
          end
        end
        return @_cached_exist
      end

      def check_rdftype_inconsistency
        self.class.goop_settings[:model]
        self.class.goop_settings[:attributes].each do |k,opts|
          pred = self.class.uri_for_predicate(k)
          if RDF.rdf_type?(pred)
            raise ArgumentError, "A model cannot use the rdf:type predicate. This is a reserved predicate for internal use."
          end
        end
      end

      def each_linked_base
        raise ArgumentError, "No block given" unless block_given?
        @attributes.each do |key,values|
          mult_values = if values.kind_of? Array then values else [values] end
          mult_values.each do |object|
            if object.kind_of? Resource
              yield key,object
            end
          end
        end
      end

      def lazy_loaded?
        internals.lazy_loaded?
      end

      def lazy_loaded
        internals.lazy_loaded
      end

      def load(*args)
        resource_id = args[0]
        opts = {}
        opts = args[1] if args.length > 1

        load_attrs = (opts.delete :load_attrs) || (self.class.goop_settings[:schemaless] ? nil : :defined)
        query_options = opts.delete :query_options
        if load_attrs == :defined
          load_attrs = self.class.goop_settings[:attributes].keys
          #do not do load stuff with query options can break things
          load_attrs.select! { |attr| self.class.attr_query_options(attr).nil? }
          load_attrs.select! { |attr| !self.class.inverse_attr?(attr) }
          load_attrs << :uuid if self.respond_to? :uuid
        elsif load_attrs == :all
          load_attrs = nil
        end
        load_attrs.delete :resource_id if load_attrs
        store_name = opts.delete :store_name

        if resource_id.nil? and internals.id(false).nil?
          raise StatusException,
            "Cannot load Resource without a resource in paramater or internals"
        end
        if resource_id.nil?
          resource_id = internals.id(false)
        end
        unless (resource_id.kind_of? SparqlRd::Resultset::Node and
               not resource_id.kind_of? SparqlRd::Resultset::Literal)
          raise ArgumentError, "resource_id must be an instance of RDF:IRI or RDF::BNode"
        end

        model_class = self.class
        unless (self.class.respond_to? :goop_settings) && (self.class.goop_settings.include? :model)
          model_class = Goo::Queries.get_resource_class(resource_id,internals.store_name)
        end
        if model_class.nil?
          raise ArgumentError, "ResourceID '#{resource_id}' does not exist"
        end
        if model_class != self.class
          raise ArgumentError,
              "ResourceID '#{resource_id}' is an instance of type #{model_class} in the store"
        end
        graph_id = nil
        collection = nil
        if self.class.goop_settings[:collection]
          unless self.internals.collection
            raise ArgumentError,
              "Find method needs collection parameter `#{self.class.goop_settings[:collection][:attribute]}`"\
              if args.length < 2
            raise ArgumentError,
              "Find method needs collection parameter `#{self.class.goop_settings[:collection][:attribute]}`"\
              unless args[1].include? self.class.goop_settings[:collection][:attribute]
            self.internals.collection = args[1][self.class.goop_settings[:collection][:attribute]]
          end
          lamb = self.class.goop_settings[:collection][:with]
          graph_id = lamb.call(self.internals.collection)
        end
        self.internals.graph_id = graph_id
        store_attributes = Goo::Queries.get_resource_attributes(resource_id, self.class,
                                                         internals.store_name, graph_id,
                                                         load_attrs,query_options,self.internals.collection)
        store_attributes = alias_rename(store_attributes)
        internal_status = @attributes[:internals]
        @attributes = store_attributes
        @attributes[:internals] = internal_status
        shape_me
        if load_attrs
          load_attrs.each do |a|
            if !@attributes.include? a and !self.class.inverse_attr?(a) and\
              !(self.class.goop_settings[:collection] and self.class.goop_settings[:collection][:attribute] == a)
              send("#{a}=",[],:in_load => true)
            end
            internals.loaded_attrs << a
          end
        end
        internals.id=resource_id
        internals.loaded
        return self
      end

      def delete(in_update=false)
        self.load unless self.loaded?
        internals.delete? unless in_update

        reached = Set.new
        reached = Goo::Queries.reachable_objects_from(resource_id, internals.store_name,
                                                      count_backlinks = true)
        to_delete = Set.new
        reached.each do |info|
          #include to delete related bnodes with no extra backlinks
          if info[:id].bnode? and info[:backlink_count] < 2
            to_delete << info[:id]
          end
        end
        objects_to_delete = [self]
        #find those extra bnodes as objects and load them.
        self.each_linked_base do |attr_name, linked_obj|
          next if in_update and not linked_obj.loaded?
          if to_delete.include? linked_obj.resource_id
            unless linked_obj.loaded?
              linked_obj.load
            end
            objects_to_delete << linked_obj
          end
        end
        queries = Goo::Queries.build_sparql_delete_query(objects_to_delete)
        if queries.length.nil? or queries.length == 0
          raise ArgumentError, "Internal error, no queries generated for delete"
        end
        epr = Goo.store(@store_name)
        queries.each do |query|
          epr.update(query)
        end

        internals.deleted
        if in_update
          return objects_to_delete
        end
        return nil
      end

      def save()
        return nil if not self.modified?
        if not valid?
            exc = NotValidException.new
              "Object is not valid. It cannot be saved. Check errors."
            exc.errors = self.internals.errors
            raise exc
        end
        self.each_linked_base do |attr_name,linked_obj|
          next unless linked_obj.internals.loaded?
          if not linked_obj.valid?
            exc = NotValidException.new
              "Attribute '#{attr_name}' links to a non-valid object."
            exc.errors = linked_obj.internals.errors
            raise exc
          end
        end
        modified_models = []
        modified_models << self if self.modified?
        Goo::Queries.recursively_collect_modified_models(self, modified_models)

        modified_models.each do |mmodel|
          if mmodel.exist?(reload=true)
            #an update: first delete a copy from the store
            copy = mmodel.class.new
            if mmodel.internals.collection
              copy.internals.collection = mmodel.internals.collection
            end
            copy.load(mmodel.resource_id)
            copy.delete(in_update=true)
          end
        end

        if modified_models.length > 0
          queries = Goo::Queries.build_sparql_update_query(modified_models)
          return nil if queries.length.nil? or queries.length == 0
          epr = Goo.store(@store_name)
          queries.each do |query|
            epr.update(query)
          end
        end

        if self.respond_to?(:uuid)
          self.resource_id=
              Goo::Queries.get_resource_id_by_uuid(self.uuid, self.class, @store_name)
        end
        self.each_linked_base do |attr_name, umodel|
          if umodel.resource_id.bnode? and umodel.modified?
            umodel.resource_id=
              Goo::Queries.get_resource_id_by_uuid(umodel.uuid, umodel.class, @store_name)
            umodel.internals.saved
          end
        end

        modified_models.each do |model|
          model.internals.saved
        end
        return self
      end

      def loaded?
        internals.loaded?
      end
      def persistent?
        internals.persistent?
      end
      def modified?
        return internals.modified? if internals.modified?
        self.each_linked_base do |attr_name,linked_obj|
          return linked_obj.modified? if linked_obj.modified?
        end
        return false
      end

      def lazy_load_attr(attr,value)
        internals.loaded_attrs << attr
        if !self.respond_to? attr
          shape_attribute(attr.to_s)
        end
        if @attributes[attr].kind_of? Array
          return if value.nil?
          @attributes[attr] << value unless @attributes[attr].include? value
        else
          value = [] if value.nil?
          send("#{attr}=",value,:in_load => true)
        end
      end

      def self.all(*args)
        (args << {:load_attrs => []}) if args.length == 0
        return self.where(*args)
      end

      def self.where(*args)
        if (args.length == 0) or (args.length > 1) or (not args[0].kind_of? Hash)
          raise ArgumentError,
            "#{self.class.name}.where accepts (attribute => value) associations or :all"
        end
        attributes = args[0]
        if attributes
          attributes.each_key do |attr|
            raise ArgumentError, "`#{attr}` value `nil` is not allowed in `where` call." if attributes[attr].nil?
          end
        end
        if attributes.include? :resource_id
          raise ArgumentError, ":resource_id is not an attribute. It cannot be used in :where"
        end
        only_known = (attributes.delete :only_known)
        only_known = true if only_known.nil?
        load_attrs = attributes.delete :load_attrs
        if load_attrs == :defined
          load_attrs = self.goop_settings[:attributes].keys
          load_attrs << :uuid if self.respond_to? :uuid
          load_attrs.select! { |attr| self.attr_query_options(attr).nil? }
          load_attrs.select! { |attr| !self.inverse_attr?(attr) }
        end
        query_options = attributes.delete :query_options
        ignore_inverse = attributes.include?(:ignore_inverse) and attributes[:ignore_inverse]
        attributes.delete(:ignore_inverse)
        epr = Goo.store(@store_name)
        collection = nil
        unless self.goop_settings[:collection].nil?
          collection = args[0][self.goop_settings[:collection][:attribute]]
        end
        search_query = Goo::Queries.search_by_attributes(
                          attributes, self, @store_name,
                          ignore_inverse, load_attrs,only_known)
        rs = epr.query(search_query,options = (query_options || {}))
        items = Hash.new
        rs.each_solution do |sol|
          resource_id = sol.get(:subject)
          if !items[resource_id.value]
            item = self.new
            item.internals.lazy_loaded
            item.resource_id = resource_id
            items[resource_id.value] = item
            if collection
              item.internals.collection = collection
              item.internals.graph_id = collection.resource_id.value
            else
              graph_id = Goo::Naming.get_graph_id(self)
              item.internals.graph_id = graph_id
            end
            item.internals.lazy_loaded
          end
          item = items[resource_id.value]
          next if load_attrs.nil?
          if load_attrs.length > 0
            sol.get_vars.each do |var|
              next if var == "subject"
              value = (sol.get var.to_sym)
              (sol_attr, sol_model) = var.split "_onmodel_"
              if self.goop_settings[:model].to_s == sol_model
                item.lazy_load_attr(sol_attr.to_sym, value)
              else
                #something nested
                #TODO
              end
            end
          end
        end
        return items.values
      end

      def self.find(*args)
        param = args[0]
        opts = {}
        opts = args[1] if args.length > 1 and args[1]

        load_attributes = opts.delete :load_attributes
        load_attributes = true if load_attributes.nil? #default
        store_name = opts.delete :store_name

        unless goop_settings[:collection].nil?
          unless opts.nil? || (opts.include? goop_settings[:collection][:attribute])
            raise ArgumentError,
              "This is a collection model that needs the attribute `#{goop_settings[:collection][:attribute]}` to run find."
          end
        end

        #with :resource_id in DSL we do not check for :unique attributes
        unless self.goop_settings[:attributes].include? :resource_id
          if (self.goop_settings[:unique][:fields].nil? or
             self.goop_settings[:unique][:fields].length != 1)
            mess = "The call #{self.name}.find cannot be used " +
                   " if the model has no `:unique => true` attributes"
            raise ArgumentError, mess
          end
        end


        if (param.kind_of? String) && goop_settings[:unique][:fields]
          key_attribute = goop_settings[:unique][:fields][0]
          ins = self.where key_attribute => param
          if ins.length > 1
            raise ArgumentError,
              "Inconsistent model behaviour. There are #{ins.length} instance with #{key_attribute} => #{param}"
          end
          return nil if ins.length == 0
          ins[0].load if load_attributes
          return ins[0]
        elsif param.kind_of? RDF::IRI
          iri = param
        else
          raise ArgumentError,
            "#{self.class.name}.find only accepts RDF::IRI as input or String if accessing :unique fields."
        end
        opts = opts.merge(store_name: store_name, load_attributes: load_attributes)
        return self.load(iri,opts)
      end

      def self.load(*args)
        resource_id = args[0]
        opts = {}
        opts = args[1] if args.length > 1

        load_attributes = opts.delete :load_attributes
        store_name = opts.delete :store_name

        model_class = self
        if model_class == Goo::Base::Resource
          model_class = Queries.get_resource_class(resource_id, store_name)
          if model_class.nil?
            return nil
          end
        end
        inst = model_class.new
        inst.load(*args)
        return inst
      end

      def errors
        return internals.errors
      end

      def attr_loaded? attr
        return (loaded? or (internals.loaded_attrs.include? attr))
      end

      def valid?
        internals.errors = Hash.new()
        self.class.attributes.each do |att,att_options|
          internals.errors[att] = []
        end
        self.class.attributes.each do |att,att_options|
          if att_options[:validators] and att_options[:validators].length > 0
            att_options[:validators].each do |val, val_options|
              if not Goo.validators.include? val
                raise ArgumentError, "Validator #{val} cannot be found"
              end
              if not val_options.include? :instance
                validator = Goo.validators[val].new(val_options)
                val_options[:instance] = validator
              end
              val_options[:instance].validate_each(self,att,@table[att])
            end
          end
        end

        new_objects_check

        internals.errors.reject! { |att,val| val.length == 0 }
        return (internals.errors.length == 0)
      end

      private
      def load_on_demand(attrs,original_attrs=nil,store_name=nil)
        graph_id = self.internals.graph_id
        if graph_id.nil?
          raise ArgumentError, "Graph ID must be known at this point"
        end
        query_options = {}
        unless original_attrs.nil?
          original_attrs.each do |attr|
            att_opts = self.class.attr_query_options(attr)
            query_options = query_options.merge(att_opts) if att_opts
          end
        end
        loaded_attributes = Queries.get_resource_attributes(resource_id, self.class,
                                                            store_name, graph_id,
                                                            attributes=attrs,
                                                            query_options=query_options,
                                                            collection=self.internals.collection)

        if original_attrs
          return loaded_attributes.values[0]
        else
          attrs.each do |attr|
            #actually we only use one value
            lazy_load_attr(attr,loaded_attributes.values[0])
          end
        end
        return loaded_attributes.values[0]
      end

      def alias_rename(atts)
        return atts if self.class.goop_settings[:alias_table].nil? || (self.class.goop_settings[:alias_table].length == 0)
        atts_out = {}
        index_table = self.class.goop_settings[:alias_table]
        atts.each do |k,v|
          if not (self.class.goop_settings[:alias_table].include? k)
            atts_out[k] = v
          else
            atts_out[index_table[k]] = v
          end
        end
        return atts_out
      end

      def new_objects_check
        #checking if there are new objects that already exist
        self.attributes.each do |att,att_options|
          values = self.attributes[att]
          next if values.nil?
          values = [values] unless values.kind_of? Array
          values.each do |value|
            if value.kind_of? Goo::Base::Resource
              next if value.persistent?
              #value is new but already exists
              if value.exist?(reload=true)
                self.internals.errors[att] = [] if self.internals.errors[att].nil?
                self.internals.errors[att] << "Attribute '#{att}' references a new object that already exists #{value.resource_id.value}"
              end
            end
          end
        end
      end
    end
  end
end
