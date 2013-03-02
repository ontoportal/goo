require 'rsolr'

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

        Goo.search_connection.add copy_to_index


        Goo.search_connection.commit :commit_attributes => {}

        #puts copy_to_index

   #     self.class.solr.add copy_to_index

      end

      def unindex
        Goo.search_connection.delete_by_id get_index_id



        Goo.search_connection.commit :commit_attributes => {}



      end


      def get_index_id
        return self.class.goop_settings[:search_options][:name_with].call(self)
      end


      module ClassMethods


        def search(q)
          response = Goo.search_connection.get 'select', :params => {:q => '*:*'}



          response["response"]["docs"].each{|doc| puts doc }



          #binding.pry
        end

        def indexBatch(collection)
        end
      end
  end
end