module Goo
  module Validators
    class Symmetric < ValidatorBase
      include Validator

      key :symmetric

      error_message ->(obj) {
        "symmetric error"
      }

      validity_check -> (obj) do
        return true if Existence.empty_value?(@value)

        return Array(@value).select{|x| not self.class.symmetric?(@attr,x, @inst)}.empty?
      end

      def self.symmetric?(attr, value, source_object)
        if self.respond_to?(attr, value)
          target_values = self.attr_value(attr, value)
          return target_values.any?{ |target_object| self.equivalent?(target_object, source_object)}
        end

        return false
      end

      def self.respond_to?(attr, object)
        object && object.respond_to?(attr)
      end

      def self.attr_value(attr, object)
        Array(object.send(attr))
      end

      def self.equivalent?(object1, object2)
        if object1.respond_to?(:id) && object2.respond_to?(:id)
          object1.id.eql?(object2.id)
        else
          object2 == object1
        end
      end
    end
  end
end