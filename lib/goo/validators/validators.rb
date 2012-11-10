##TODO need to fix this for dynamic loading. Just good like for the moment.
#module Goo
#  module Validators
    class DateTimeXsdValidator < ActiveModel::EachValidator 
      def validate_each(record, attribute, value)
        begin
          #why do I need module here.
          datetime = Goo::Utils.xsd_date_time_parse(value)
          if not datetime
            record.errors[attribute] << \
              (options[:message] || "#{attribute}=#{value} is not an XSD Datetime string")
          end
        rescue ArgumentError => e
          record.errors[attribute] << \
           (options[:message] || "#{attribute}= #{value} is not an XSD Datetime #{e.message}")
        end
      end
    end

    class CardinalityValidator < ActiveModel::EachValidator 
      def validate_each(record, attribute, value)
        raise ArgumentError, "CardinalityValidator for #{attribute} needs options :maximum and/or :minimun." \
          if options.length == 0

        [:maximum, :minimun].each do |attr|
          raise ArgumentError, "#{attr} has to be a non-negative integer " \
            unless not options[attr] or (options[attr].instance_of?(Fixnum) or options[attr] >= 0)
        end
        
        #presence should catch this validation
        return if value == nil

        if value.kind_of?(Array)
          if (options[:minimum]  and value.length < options[:minimum]) or \
              (options[:maximum]  and value.length > options[:maximum])
            record.errors[attribute] << \
            (options[:message] || "#{attribute}.length = #{value.length}. It does not satisfy cardinality #{options}")
          end
        else
          #TODO: cardinality check for non-array values. 
          if options[:minimum] and options[:minimum] > 1
            record.errors[attribute] << \
            (options[:message] || "#{attribute}.length = #{value.length}. It does not satisfy cardinality #{options}")
          end
        end
      end
    end 
#  end
#end
