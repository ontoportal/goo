module Goo
  module Validators
    class ValueRange < ValidatorBase
      include Validator

      keys [:min_, :max_]

      error_message ->(obj) {
        value = self.value_length(@value)
        if @type == :min
          "#{@attr} value has length `#{value}` and the min length is `#{@range}`"
        else
          "#{@attr} value has length `#{value}` and the max length is `#{@range}`"
        end
      }

      validity_check -> (obj) do
        self.enforce_range_length(@type, @range, @value)
      end

      def initialize(inst, attr, value, type)
        super(inst, attr, value)
        @type = type.index("max_") ? :max : :min
        @range = self.range(type)
      end

      def enforce_range_length(type_range, range, value)
        return false if value.nil?
        value_length = self.value_length(value)

        (type_range.eql?(:min) && (value_length >= range)) || (type_range.eql?(:max) && (value_length <= range))
      end

      def range(opt)
        opt[4..opt.length].to_i
      end

      def value_length(value)
        return 0 if value.nil?

        if value.is_a?(String) || value.is_a?(Array)
          value.length
        else
          value
        end
      end
    end
  end
end
