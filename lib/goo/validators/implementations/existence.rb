module Goo
  module Validators
    class Existence < ValidatorBase
      include Validator

      key :existence

      error_message ->(obj) { "`#{@value}` value cannot be nil"}

      validity_check -> (obj) do
        not (@value.nil? || self.class.empty?(@value) || self.class.empty_array?(@value))
      end

      def self.empty?(value)
        empty_string?(value) || empty_to_s?(value)
      end
      def self.empty_string?(string)
        string.is_a?(String) && string.strip.empty?
      end

      def self.empty_to_s?(object)
        object && object.to_s&.strip.empty?
      end

      def self.empty_array?(array)
        array.is_a?(Array) && array && array.reject{|x|  x.nil? || empty?(x)}.empty?
      end
    end
  end
end