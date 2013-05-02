module Goo
  module Base

    class Pattern
      attr_reader :patterns

      def initialize(*args)
        @patterns = [args.first]
      end

      def join(*args)
        join_pattern = Join.new(self)
        join_pattern.patterns << args.first
        return join_pattern
      end

      def union(*args)
        union_pattern = Union.new(self)
        union_pattern.patterns << args.first
        return union_pattern
      end
    end #Pattern

    class Union < Pattern
    end

    class Join < Pattern
    end

    class PatternIteration

      attr_reader :pattern

      def initialize(patterns)
        @patterns = patterns
      end

      def recursive_each(patterns,&block)
        patterns = patterns.patterns if patterns.kind_of?(Pattern)
        patterns.each do |pat|
          if pat.kind_of?(Pattern)
            recursive_each(pat.patterns,&block)
          else
            attr = pat.keys.first
            value = pat[attr]
            yield [attr,value] 
          end
        end
      end

      def each(&block)
        recursive_each(@patterns,&block)
      end
    end

  end #Base
end #Goo
