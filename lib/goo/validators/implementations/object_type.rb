module Goo
  module Validators
    class ObjectType < ValidatorBase
      include Validator

      key :object_type

      error_message ->(obj) {
        if @error.eql?(:persistence)
          "`#{@attr}` contains non persistent models. It will not save."
        else
          "`#{@attr}` contains values that are not instance of `#{@model_range.model_name}`"
        end
      }

      validity_check -> (obj) do
        values = Array(@value)

        unless values.select { |v| !self.is_a_model?(v, @model_range) }.empty?
          @error = :no_range
          return false
        end

        unless values.select { |v| !self.persistent?(v) }.empty?
          @error = :persistence
          return false
        end

        return true
      end

      def initialize(inst, attr, value, model_range)
        super(inst, attr, value)
        @model_range = model_range
      end

      def is_a_model?(value, model_range)
        value.is_a?(model_range) || (value.respond_to?(:klass) && value[:klass] == model_range)
      end

      def persistent?(value)
        value.respond_to?(:klass) || value.persistent?
      end
    end
  end
end
