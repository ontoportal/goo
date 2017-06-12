require 'rsolr'

module Goo

  module Search

    def self.included(base)
        base.extend(ClassMethods)
      end

      def index(connection_name=:main)
        raise ArgumentError, "ID must be set to be able to index" if @id.nil?
        doc = get_indexable_object
        #solr wants resource_id instead of :id
        Goo.search_connection(connection_name).add(doc)
      end

      def unindex(connection_name=:main)
        id = get_index_id
        Goo.search_connection(connection_name).delete_by_id(id)
      end

      def get_index_id()
        self.class.model_settings[:search_options][:index_id].call(self)
      end

      def get_indexable_object()
        doc = self.class.model_settings[:search_options][:document].call(self)
        #in solr
        doc[:resource_id] = doc[:id].to_s
        doc[:id] = get_index_id.to_s
        # id: clsUri_ONTO-ACRO_submissionNumber. i.e.: http://lod.nal.usda.gov/nalt/5260_NALT_4
        doc
      end

      module ClassMethods

        def search_options(*args)
          @model_settings[:search_options] = args.first
        end

        def search(q, params={}, connection_name=:main)
          params["q"] = q
          Goo.search_connection(connection_name).post('select', :data => params)
        end

        def indexBatch(collection, connection_name=:main)
          docs = Array.new
          collection.each do |c|
            docs << c.get_indexable_object
          end

          Goo.search_connection(connection_name).add(docs)
        end

        def unindexBatch(collection, connection_name=:main)
          docs = Array.new
          collection.each do |c|
            docs << c.get_index_id
          end

          Goo.search_connection(connection_name).delete_by_id(docs)
        end

        def unindexByQuery(query, connection_name=:main)
          Goo.search_connection(connection_name).delete_by_query(query)
        end

        def indexCommit(attrs=nil, connection_name=:main)
          Goo.search_connection(connection_name).commit(:commit_attributes => attrs || {})
        end

        def indexOptimize(attrs=nil, connection_name=:main)
          Goo.search_connection(connection_name).optimize(:optimize_attributes => attrs || {})
        end

        def indexClear(connection_name=:main)
          # WARNING: this deletes ALL data from the index
          unindexByQuery("*:*", connection_name)
        end
      end
  end
end
