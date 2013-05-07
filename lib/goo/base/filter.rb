module Goo
  module Base
    FILTER_TUPLE = Struct.new(:operator, :value)
    class Filter
      attr_reader :pattern
      attr_reader :filter_tree

      def initialize(pattern)
        @pattern = pattern
        @filter_tree = []
      end

      def >(value)
        @filter_tree << FILTER_TUPLE.new(:>,value)
        self
      end

      def <(value)
        @filter_tree << FILTER_TUPLE.new(:<,value)
        self
      end

      def <=(value)
        @filter_tree << FILTER_TUPLE.new(:<=,value)
        self
      end

      def >=(value)
        @filter_tree << FILTER_TUPLE.new(:>=,value)
        self
      end

      def or(value)
        @filter_tree << FILTER_TUPLE.new(:or,value)
        self
      end

      def and(value)
        @filter_tree << FILTER_TUPLE.new(:and,value)
        self
      end
    end
  end
end
