
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

      end

      module ClassMethods
        def search(q)
          puts "search !!!!"
          binding.pry
        end

        def indexBatch(collection)
        end
      end
  end
end
