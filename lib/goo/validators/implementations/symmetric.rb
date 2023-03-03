module Goo
  module Validators
    class Symmetric < ValidatorBase
      include Validator

      key :symmetric

      error_message ->(obj) {
        "`#{@attr}` must be symmetric"
      }

      validity_check -> (obj) do
        return true if self.class.empty_value?(@value)

        return Array(@value).select{|x| not symmetric?(@attr,x, @inst)}.empty?
      end

      def symmetric?(attr, value, source_object)
        if respond_to?(attr, value)
          target_values = self.class.attr_value(attr, value)
          return target_values.any?{ |target_object| self.class.equivalent_value?(target_object, source_object)}
        end

        return false
      end

      def respond_to?(attr, object)
        object && object.respond_to?(attr)
      end

    end
  end
end