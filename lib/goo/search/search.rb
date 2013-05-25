require 'rsolr'

module Goo

  module Search

    def self.included(base)
        base.extend(ClassMethods)
      end

      def index()
        raise ArgumentError, "ID must be set to be able to index" if @id.nil?
        doc = get_indexable_object()
        #solr wants resource_id instead of :id
        Goo.search_connection.add(doc)
      end

      def unindex()
        id = get_index_id()
        Goo.search_connection.delete_by_id(id)
      end

      def get_index_id()
        return self.class.model_settings[:search_options][:index_id].call(self)
      end

      def get_indexable_object()
        doc = self.class.model_settings[:search_options][:document].call(self)
        #in solr
        doc[:resource_id] = doc[:id].to_s
        doc[:id] = get_index_id().to_s
        return doc
      end

      module ClassMethods

        def search_options(*args)
          @model_settings[:search_options] = args.first
        end
        
        def search(q, params={})
          params["q"] = q
          response = Goo.search_connection.get('select', :params => params)
          return response
        end

        def indexBatch(collection)
          docs = Array.new
          collection.each do |c|
            docs << c.get_indexable_object()
          end

          Goo.search_connection.add(docs)
        end

        def unindexBatch(collection)
          docs = Array.new
          collection.each do |c|
            docs << c.get_index_id()
          end

          Goo.search_connection.delete_by_id(docs)
        end

        def unindexByQuery(query)
          Goo.search_connection.delete_by_query(query)
        end

        def indexCommit(attrs=nil)
          Goo.search_connection.commit(:commit_attributes => attrs || {})
        end

        def indexOptimize(attrs=nil)
          Goo.search_connection.optimize(:optimize_attributes => attrs || {})
        end

        def indexClear()
          # WARNING: this deletes ALL data from the index
          unindexByQuery("*:*")
        end
      end
  end
end
