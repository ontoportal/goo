
module Goo
  module Base

    class AttributeValueProxy
      def initialize(validator,internals)
        @validator = validator
        @internals = internals
      end

      def cardinality_transform(attr, value, current_value)
        if @validator.nil?
          unless value.kind_of? Array
            raise ArgumentError, "Attribute '#{attr} must be an array. No cardinality configured.'"
          end
          return value
        end
        if value.kind_of? Array
          if @validator.options[:maximum] and value.length > @validator.options[:maximum] 
            raise ArgumentError, "Attribute '#{attr}' does not satisfy max cardinality."
          end
          if @validator.options[:minimun] and value.length < @validator.options[:minimun]
            raise ArgumentError, "Attribute '#{attr}' does not satisfy min cardinality."
          end
          if @validator.options[:maximum] and @validator.options[:maximum] == 1
            return value[0]
          end
        else #not an array
          if (not @validator.options[:maximum]) or @validator.options[:maximum] > 1
            return [value]
          end
          if @validator.options[:maximum] and @validator.options[:maximum] == 1
            return value
          end
          if @validator.options[:minimun] and @validator.options[:minimun] > 0
            return [value]
          end
        end
        if not value.kind_of? Array and current_value.kind_of? Array
          raise ArgumentError, 
                  "Multiple value objects cannot be replaced for non-array objects"
        end
        if value.kind_of? Array then value else [value] end
      end

      def call(*args)
        options = args[0]
        value = options[:value][0]
        attr = options[:attr]
        current_value = options[:current_value]
        tvalue = cardinality_transform(attr,value,current_value)
      end
    end
  end
end
