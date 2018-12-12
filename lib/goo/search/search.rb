require 'rsolr'

module Goo

  module Search

    def self.included(base)
      base.extend(ClassMethods)
    end

    def index(connection_name=:main)
      raise ArgumentError, "ID must be set to be able to index" if @id.nil?
      doc = indexable_object
      #solr wants resource_id instead of :id
      Goo.search_connection(connection_name).add(doc)
    end

    def unindex(connection_name=:main)
      id = index_id
      Goo.search_connection(connection_name).delete_by_id(id)
    end

    # default implementation, should be overridden by child class
    def index_id()
      raise ArgumentError, "ID must be set to be able to index" if @id.nil?
      @id.to_s
    end

    # default implementation, should be overridden by child class
    def index_doc()
      raise NoMethodError, "You must define method index_doc in your class for it to be indexable"
    end

    def indexable_object()
      doc = index_doc
      doc[:resource_id] = doc[:id].to_s
      doc[:id] = index_id.to_s
      doc
    end


    module ClassMethods

      def search(q, params={}, connection_name=:main)
        params["q"] = q
        Goo.search_connection(connection_name).post('select', :data => params)
      end

      def indexBatch(collection, connection_name=:main)
        docs = Array.new
        collection.each do |c|
          docs << c.indexable_object
        end
        Goo.search_connection(connection_name).add(docs)
      end

      def unindexBatch(collection, connection_name=:main)
        docs = Array.new
        collection.each do |c|
          docs << c.index_id
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
