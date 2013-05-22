module Goo
  module Base
    module Enum 
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def init_enum
          @model_settings[:enum][:values].each do |value|
            instance = self.new(@model_settings[:enum][:attribute] => value)
            instance.save unless instance.exist?
          end
          @model_settings[:enum][:initialize]=true
        end
        def find(*opts)
          unless @model_settings[:enum][:initialize]
            @model_settings[:enum][:lock].synchronize do
              init_enum unless @model_settings[:enum][:initialize]
            end
          end
          super(*opts)
        end
        def where(*opts)
          unless @model_settings[:enum][:initialize]
            @model_settings[:enum][:lock].synchronize do
              init_enum unless @model_settings[:enum][:initialize]
            end
          end
          super(*opts)
        end
      end
    end
  end
end
