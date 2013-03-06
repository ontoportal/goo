module Goo
  module Base

    class Page < Array
      attr_accessor :page
      attr_accessor :prev_page
      attr_accessor :next_page
      attr_accessor :page_count

      def initialize(page,next_page,page_count,data)
        super()
        @page = page
        @page_count = page_count
        @prev_page = page > 1 ? page - 1 : nil
        @next_page = next_page ? page+1 : nil
        self.concat data
      end

    end

  end
end
