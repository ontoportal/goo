
module Goo
  module Base
    module Settings

      #TODO: this looks ugly.
      @@MODELS = Set.new
      def self.models
        @@MODELS
      end

      def self.find_model_by_uri(uri)
        @@MODELS.each do |model|
          model.goop_settings[:model]
          uri_model = Goo::Naming.get_vocabularies.uri_for_type model
          return model if uri_model == uri
        end
        return nil
      end

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        attr_accessor :goop_settings

        def model(type)
          if instance_variables.index(:@goop_settings) == nil
            @goop_settings = {}
          end
          Settings.models << self
          @goop_settings[:model] = type
          @goop_settings[:graph_policy] =
            @goop_settings[:graph_policy] || :type_id_graph_policy
          @goop_settings[:unique] = { :generator => :anonymous }
        end

        def unique(*args)
          if args[-1].is_a?(Hash)
            options = args.pop
          else
            options = {}
          end
          options[:generator] = options[:generator] || :concat_and_encode
          options[:policy] = options[:policy] || :unique
          unique_context = { :fields => args }.merge(options)
          @goop_settings[:unique] = unique_context
        end

        def graph_policy(graph_policy)
          @goop_settings[:graph_policy] = graph_policy
        end

        def save_policy(save_policy)
          @goop_settings[:save_policy] = save_policy
        end

        def depends(*dependencies)
          @goop_settings[:depends] = []
          @goop_settings[:depends] << dependencies
        end

      end

    end
  end
end
