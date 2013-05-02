module Goo
  module Base
    class Pattern
      attr_reader :patterns
      attr_reader :operations

      def initialize(*args)
        @patterns = [args.first]
        @operations = []
      end
      def and(*args)
        @patterns << args.first
        @operations << :and
        return self
      end
      def or(*args)
        @patterns << args.first
        @operations << :or
        return self
      end
    end
  end
end
