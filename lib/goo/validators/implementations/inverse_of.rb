module Goo
  module Validators
    class InverseOf < ValidatorBase
      include Validator

      key :inverse_of_

      error_message ->(obj) {
        "`#{@attr}` must be the inverse of ``#{@property}``"
      }

      validity_check -> (obj) do
        return true if self.class.empty_value?(@value)

        return Array(@value).select{|x| not inverse?(@property,x, @inst)}.empty?
      end

      def initialize(inst, attr, value, key)
        super(inst, attr, value)
        @property = self.class.property(key)
      end

      def inverse?(attr, value, source_object)
        if self.class.respond_to?(attr, value)
          target_values = self.class.attr_value(attr, value)
          return target_values.any?{ |target_object| self.class.equivalent_value?(target_object, source_object)}
        end

        false
      end


    end
  end
end