require 'rsolr'


SOLR_URL = "http://ncbo-dev-app-02.stanford.edu:8080/solr/"


module Goo


  module Search

      def self.included(base)
        base.extend(ClassMethods)
      end

      def index
        object_id = self.resource_id.value
        copy_to_index = self.attributes.dup
        copy_to_index.delete :internals

        copy_to_index[:resource_id] = object_id

        copy_to_index[:termId] = copy_to_index[:id]

        copy_to_index[:id] = get_index_id

        #document = JSON.dump copy_to_index

        self.class.solr.add copy_to_index


        self.class.solr.commit :commit_attributes => {}

        #puts copy_to_index

   #     self.class.solr.add copy_to_index

      end

      def unindex
        self.class.solr.delete_by_id get_index_id



        self.class.solr.commit :commit_attributes => {}



      end


      def get_index_id
        return self.attributes[:id] + "_" + self.attributes[:submission]
      end


      module ClassMethods
        @@solr = RSolr.connect :url => SOLR_URL

        def solr
          @@solr
        end

        def search(q)
          response = @@solr.get 'select', :params => {:q => '*:*'}



          response["response"]["docs"].each{|doc| puts doc["id"] }



          #binding.pry
        end

        def indexBatch(collection)
        end
      end
  end
end