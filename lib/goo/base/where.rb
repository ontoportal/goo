module Goo
  module Base

    class Where

      AGGREGATE_PATTERN = Struct.new(:pattern,:aggregate)

      attr_accessor :where_options_load

      def initialize(klass,*match_patterns)
        @klass = klass
        @pattern = match_patterns.first.nil? ? nil : Pattern.new(match_patterns.first) 
        @models = nil
        @include = []
        @include_embed = {}
        @result = nil
        @filters = nil
        @ids = nil
        @aggregate = nil
        @where_options_load = nil
      end

      def process_query
        @include << @include_embed if @include_embed.length > 0

        options_load = { models: @models, include: @include, ids: @ids,
                         graph_match: @pattern, klass: @klass,
                         filters: @filters , aggregate: @aggregate}

        options_load.merge!(@where_options_load) if @where_options_load

        if !@klass.collection_opts.nil? and !options_load.include?(:collection)
          raise ArgumentError, "Collection needed call `#{@klass.name}.find`"
        end

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
        @include = [:unmapped] if @include.include? :unspecified
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

      def in(collection)
        if collection
          (@where_options_load ||= {})[:collection] = collection
        end
        self
      end

      def ids(ids)
        if ids
          @ids = ids
        end
        self
      end

      def filter(filter)
        (@filters ||= []) << filter
        self
      end

      def aggregate(agg,pattern)
        (@aggregate ||= []) << AGGREGATE_PATTERN.new(pattern,agg) 
        self
      end

      def nil?
        self.first.nil?
      end
    end
  end
end

