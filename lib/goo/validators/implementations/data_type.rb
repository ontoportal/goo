require 'uri'

module Goo
  module Validators
    class DataType < ValidatorBase
      include Validator
      MAX_URL_LENGTH = 2048

      keys %i[list uri url string integer boolean date_time float]

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
          enforce_type_boolean(value)
        elsif type.eql?(:uri) || type.eql?(RDF::URI)
          enforce_type_uri(value)
        elsif type.eql?(:url)
          enforce_type_url(value)
        elsif type.eql?(Array)
          value.is_a?(Array)
        elsif value.is_a?(Array)
          value.all? { |x| x.is_a?(type) }
        else
          value.is_a?(type)
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

      def enforce_type_url(value)
        return true if value.nil?
        return value.all? { |x| url?(x) } if value.is_a?(Array)
        url?(value)
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

      def url?(value)
        s = value.to_s
        return false if s.empty? || s.length > MAX_URL_LENGTH

        uri = URI.parse(s)
        uri.is_a?(URI::HTTP) && uri.host && !uri.host.empty?
      rescue URI::InvalidURIError
        false
      end
    end
  end
end
