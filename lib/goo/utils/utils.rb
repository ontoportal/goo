require 'date'
require "uri"

require_relative "string_utils"
require_relative "datetime_utils"
require_relative "fixnum_utils"
require_relative "boolean_utils"
require_relative "rdf"

module Goo
  module Utils

    def self.xsd_date_time_parse(v)
      values = if v.kind_of? Array then v else [v] end
      values.each do |date|
        if date.instance_of? DateTime
          date
        elsif date.instance_of? String
          DateTime.xmlschema(date)
        else
          raise ArgumentError, "#{date} is not a parsable object String or DateTime"
        end
      end
    end
  end
end
