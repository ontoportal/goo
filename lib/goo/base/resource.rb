require_relative "settings/settings"

module Goo
  module Base

    class Resource
      include Goo::Base::Settings
      #include Goo::Search

      attr_reader :loaded_attributes
      attr_reader :modified_attributes

      attr_accessor :id

      def initialize(*args)
        options = args[0] || {}
        attributes = options[:attributes]
        @loaded_attributes = Set.new
        @modified_attributes = Set.new
        @persistent = false || options[:persistent]
      end
    end
  end
end
