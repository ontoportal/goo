module Goo
  module Base
    class Filter
      def initialize()
        @filter_tree = []
      end

      def >(value)
        @filter_tree << [:>,value]
        self
      end

      def <(value)
        @filter_tree << [:<,value]
        self
      end

      def <=(value)
        @filter_tree << [:<=,value]
        self
      end

      def >=(value)
        @filter_tree << [:>=,value]
        self
      end

      def or
        @filter_tree << [:or,value]
        self
      end

      def and
        @filter_tree << [:and,value]
        self
      end
    end
  end
end
