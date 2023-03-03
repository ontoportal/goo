module Goo
  module Validators
    class DataType < ValidatorBase
      include Validator

      keys [:list, :uri, :string, :integer, :boolean, :date_time, :float]

      error_message ->(obj) {
        if @value.kind_of? Array
          return "All values in attribute `#{@attr}` must be `#{@type}`"
        else
          return "Attribute `#{@attr}` with the value `#{@value}` must be `#{@type}`"

        end
      }

      validity_check -> (obj) do
        self.enforce_type(@type, @value)
      end

      def initialize(inst, attr, value, type)
        super(inst, attr, value)
        @type = type
      end



      def enforce_type(type, value)
        return true if value.nil?

        if type == :boolean
          return self.enforce_type_boolean(value)
        elsif type.eql?(:uri) || type.eql?(RDF::URI)
          return  self.enforce_type_uri(value)
        elsif type.eql?(:uri) || type.eql?(Array)
          return value.is_a? Array
        else
          if value.is_a? Array
            return value.select{|x| !x.is_a?(type)}.empty?
          else
            return value.is_a? type
          end
        end

      end

      def enforce_type_uri(value)
        return true  if value.nil?

        value.is_a?(RDF::URI) && value.valid?
      end

      def enforce_type_boolean(value)
        if value.kind_of? Array
          return value.select { |x| !is_a_boolean?(x) }.empty?
        else
          return  is_a_boolean?(value)
        end
      end

      def is_a_boolean?(value)
        return (value.class == TrueClass) || (value.class == FalseClass)
      end
    end
  end
end