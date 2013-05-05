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

      def recursive_each(patterns,pre_union,&block)
        union = (pre_union || patterns.kind_of?(Union))
        union &&= !patterns.kind_of?(Join)
        sub_patterns = patterns.kind_of?(Pattern) ? patterns.patterns : patterns
        sub_patterns.each do |pat|
          if pat.kind_of?(Pattern)
            union = (union || pre_union || pat.kind_of?(Union)) && (!pat.kind_of?(Join))
            recursive_each(pat.patterns,union,&block)
          else
            yield [pat,union && !patterns.kind_of?(Join)]
          end
        end
      end

      def each(&block)
        recursive_each(@patterns,false,&block)
      end
    end

  end #Base
end #Goo
