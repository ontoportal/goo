
module Goo
  module Validators
    module Enforce

      def self.enforce_by_attribute(model,attr)
        return model.model_settings[:attributes][attr][:enforce]
      end

      def enforce_type(attr,type,value)
        errors = []
        if value.kind_of? Array
          if (value.select {|x| !(x.kind_of? type)} ).length > 0
            errors <<  "All values in attribute (#{attr}) must be a `#{type.name}` instance " 
          end
        else
          if !(value.kind_of? type)
            errors <<  "#{attr} value (#{value}) must be a `#{type.name}` instance " 
          end
        end
        return errors
      end

      def self.enforce_range_length(type_range,attr,opt_s,value)
        errors = []
        if !(value.kind_of?(Array) || value.kind_of?(String))
          errors << "#{attr} value (#{value}) must be an Array or String - it has range length constraints"
        end
        range = opt_s[4..opt_s.length].to_i
        if type_range == :min
          if value.length < range
            errors "#{attr} value has length `#{value.length}` and the min length is `#{range}`"
          end
        else
          if value.length > range
            errors <<  "#{attr} value has length `#{value.length}` and the max length is `#{range}`"
          end
        end
        return errors
      end

      def self.enforce(inst,attr,value)
        errors = []
        enforce_opts = enforce_by_attribute(inst.class,attr)
        enforce_opts.each do |opt|
          case opt 
           when :existence
            errors << "#{attr} value (#{value}) cannot be nil" if value.nil?
           when :list, Array
            errors << "#{attr} value (#{value}) must be an Array" if !(value.kind_of? Array)
           when :string, String
             errors += enforce_type(attr,String,value)
           when :integer, Fixnum
             errors += enforce_type(attr,Fixnum,value)
           when :date_time, DateTime
             errors += enforce_type(attr,DateTime,value)
           else
             model = Goo.model_by_name(opt)
             if model
               binding.pry
             end
             opt_s = opt.to_s
             if opt_s.index("max_") == 0
               errors += enforce_range_length(:max,attr,opt_s,value)
             end
             if opt_s.index("min_") == 0
               errors += enforce_range_length(:min,attr,opt_s,value)
             end
           end
        end
      end
    end
  end
end
