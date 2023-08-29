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
          self.enforce_type_boolean(value)
        elsif type.eql?(:uri) || type.eql?(RDF::URI)
          self.enforce_type_uri(value)
        elsif type.eql?(:uri) || type.eql?(Array)
          value.is_a? Array
        else
          if value.is_a? Array
             value.select{|x| !x.is_a?(type)}.empty?
          else
             value.is_a? type
          end
        end

      end

      def enforce_type_uri(value)
        return true  if value.nil?

        if value.kind_of? Array
          value.select { |x| !is_a_uri?(x) }.empty?
        else
          is_a_uri?(value)
        end

      end

      def enforce_type_boolean(value)
        if value.kind_of? Array
          value.select { |x| !is_a_boolean?(x) }.empty?
        else
          is_a_boolean?(value)
        end
      end

      def is_a_boolean?(value)
         (value.class == TrueClass) || (value.class == FalseClass)
      end

      def is_a_uri?(value)
        value.is_a?(RDF::URI) && value.valid?
      end
    end
  end
end