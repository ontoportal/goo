
module Goo
  module Validators
    module Enforce

      def self.enforce_by_attribute(model,attr)
        return model.model_settings[:attributes][attr][:enforce]
      end

      def self.enforce_type_boolean(attr,value)
        if value.kind_of? Array
          if (value.select {|x| !((x.class == TrueClass) || (x.class == FalseClass))} ).length > 0
            return  "All values in attribute `#{attr}` must be `Boolean`"
          end
        else
          if !((value.class == TrueClass) || (value.class == FalseClass))
            return  "Attribute `#{attr}` value `#{value}` must be a `Boolean`"
          end
        end
      end

      def self.enforce_type(attr,type,value)
        if type == :boolean
          return self.enforce_type_boolean(attr,value)
        end
        if value.kind_of? Array
          if (value.select {|x| !(x.kind_of? type)} ).length > 0
            return  "All values in attribute `#{attr}` must be `#{type.name}`"
          end
        else
          if !(value.kind_of? type)
            return  "Attribute `#{attr}` value `#{value}` must be a `#{type.name}`"
          end
        end
      end

      def self.enforce_range_length(type_range,attr,opt_s,value)
        if !value.nil? && !(value.kind_of?(Array) || value.kind_of?(String))
          return "#{attr} value (#{value}) must be an Array or String - it has range length constraints"
        end
        range = opt_s[4..opt_s.length].to_i
        if type_range == :min
          if !value.nil? && (value.length < range)
            return "#{attr} value has length `#{value.length}` and the min length is `#{range}`"
          end
        else
          if !value.nil? && (value.length > range)
            return "#{attr} value has length `#{value.length}` and the max length is `#{range}`"
          end
        end
      end

      def self.enforce(inst,attr,value)
        enforce_opts = enforce_by_attribute(inst.class,attr)
        return nil if enforce_opts.nil? or enforce_opts.length == 0
        errors_by_opt = {}
        enforce_opts.each do |opt|
          case opt
          when :unique
            unless value.nil?
              dup = Goo::SPARQL::Queries.duplicate_attribute_value?(inst,attr)
              if dup
                add_error(opt, errors_by_opt,
                "`#{attr}` must be unique. " +
                "There are other model instances with the same attribute value `#{value}`.")
              end
            end
          when :no_list
            if value.kind_of? Array
              add_error(opt, errors_by_opt,
                      "`#{attr}` is defined as non Array - it cannot hold multiple values")
            end
          when :existence
            add_error(opt, errors_by_opt, "`#{attr}` value cannot be nil") if value.nil?
          when :list, Array
            if !value.nil? && !(value.kind_of? Array)
              add_error(opt, errors_by_opt, "`#{attr}` value must be an Array")
            end
          when :uri, RDF::URI
            add_error(opt, errors_by_opt, enforce_type(attr,RDF::URI,value)) unless value.nil?
          when :string, String
            add_error(opt, errors_by_opt, enforce_type(attr,String,value)) unless value.nil?
          when :integer, Integer
            add_error(opt, errors_by_opt, enforce_type(attr,Integer,value)) unless value.nil?
          when :boolean
            add_error(opt, errors_by_opt, enforce_type(attr,:boolean,value)) unless value.nil?
          when :date_time, DateTime
            add_error(opt, errors_by_opt, enforce_type(attr,DateTime,value)) unless value.nil?
          when Proc
            # This should return an array like [:name_of_error1, "Error message 1", :name_of_error2, "Error message 2"]
            errors = opt.call(inst, attr)
            errors.each_slice(2) do |e|
              next if e.nil? || e.compact.empty?
              add_error(e[0].to_sym, errors_by_opt, e[1]) rescue binding.pry
            end
          else
            model_range = opt.respond_to?(:shape_attribute) ? opt : Goo.model_by_name(opt)
            if model_range and !value.nil?
              values = value.kind_of?(Array) ? value : [value]
              values.each do |v|
                if (!v.kind_of?(model_range)) && !(v.respond_to?(:klass) && v[:klass] == model_range)
                  add_error(model_range.model_name, errors_by_opt,
                            "`#{attr}` contains values that are not instance of `#{model_range.model_name}`")
                else
                  if !v.respond_to?(:klass) && !v.persistent?
                    add_error(model_range.model_name, errors_by_opt,
                              "`#{attr}` contains non persistent models. It will not save.")
                  end
                end
              end
            end
            opt_s = opt.to_s
            if opt_s.index("max_") == 0
              add_error(:max, errors_by_opt, enforce_range_length(:max,attr,opt_s,value)) unless value.nil?
            end
            if opt_s.index("min_") == 0
              add_error(:min, errors_by_opt, enforce_range_length(:min,attr,opt_s,value)) unless value.nil?
            end
          end
        end
        return errors_by_opt.length > 0 ? errors_by_opt : nil
      end

      def self.add_error(opt, h, err)
        return if err.nil?
        h[opt] = err
      end
    end
  end
end
