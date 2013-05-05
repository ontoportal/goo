module Goo
  module Base

    class Where

      def initialize(klass,*match_patterns)
        @klass = klass
        @pattern = match_patterns.first.nil? ? nil : Pattern.new(match_patterns.first) 
        @models = nil
        @include = []
        @include_embed = {}
        @result = nil
      end

      def process_query
        @include << @include_embed if @include_embed.length > 0

        options_load = { models: @models, include: @include, graph_match: @pattern, klass: @klass }
        models_by_id = Goo::SPARQL::Queries.model_load(options_load)
        @result = models_by_id.values
      end

      def all
        process_query unless @result
        @result
      end

      def each(&block)
        process_query unless @result
        @result.each do |r|
          yield r
        end
      end

      def length
        process_query unless @result
        return @result.length
      end

      def empty?
        process_query unless @result
        return @result.empty?
      end

      def first
        process_query unless @result
        @result.first
      end

      def last
        process_query unless @result
        @result.last
      end

      def include(*options)
        if options.instance_of?(Array) && options.first.instance_of?(Array)
          options = options.first
        end
        options.each do |opt|
          @include << opt if opt.instance_of?(Symbol)
          @include_embed.merge!(opt) if opt.instance_of?(Hash)
        end
        self
      end
      
      def models(models)
        @models = models
        self
      end

      def and(*options)
        and_match = options.first
        @pattern = @pattern.join(and_match)
        self
      end

      def or(*options)
        or_match = options.first
        @pattern = @pattern.union(or_match)
        self
      end

      def order
      end

      def filter
      end

      def aggregate
      end
    end
  end
end

