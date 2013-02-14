require 'rsolr'


SOLR_URL = "http://ncbo-dev-app-02.stanford.edu:8080/solr/"


module Goo


  module Search

      def self.included(base)
        base.extend(ClassMethods)
      end

      def index
        puts "index !!!!"
        object_id = self.resource_id.value
        copy_to_index = self.attributes.dup
        copy_to_index.delete :internals
        copy_to_index[:resource_id] = object_id
        document = JSON.dump copy_to_index

        #solr = RSolr.connect :url => SOLR_URL
        #solr.add document

        self.class.solr.add document

      end

      def unindex
         self.class.solr.delete_by_id self.id
      end

      module ClassMethods
        attr_reader :solr
        @solr = RSolr.connect :url => SOLR_URL

        def search(q)
          puts "search !!!!"

          resp = solr.get 'select', :params => {:q => q}



          binding.pry
        end

        def indexBatch(collection)
        end
      end
  end
end