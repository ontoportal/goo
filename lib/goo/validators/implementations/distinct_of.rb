module Goo
  module Validators
    class DistinctOf < ValidatorBase
      include Validator

      key :distinct_of_

      error_message ->(obj) { "`#{@attr}` must be distinct of `#{@property}`"}

      validity_check -> (obj) do
        return true if self.class.empty_value?(@value)

        self.distinct?(@inst, @property, @value)
      end

      def initialize(inst, attr, value, key)
        super(inst, attr, value)
        @property = self.class.property(key)
      end



      def distinct?(inst, property, value)
        target_values = self.class.attr_value(property, inst)
        current_values = Array(value)

        !current_values.any?{ |x| self.find_any?(target_values, x)}
      end
      def find_any?(array, value)
        array.any?{ |x| self.class.equivalent_value?(value, x)}
      end
    end
  end
end