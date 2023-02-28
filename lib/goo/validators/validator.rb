module Goo
  module Validators

    class ValidatorBase

      def initialize(inst, attr, value)
        @inst = inst
        @attr = attr
        @value = value
      end

      def valid?
        self.instance_eval(&self.class.validator_settings[:check])
      end

      def error
        message =  self.class.validator_settings[:message]
        if message.is_a? Proc
          self.instance_eval(&message)
        else
          message
        end
      end

    end

    module Validator

      def self.included(base)
        base.extend(ClassMethods)
      end


      module ClassMethods

        def key(id)
          validator_settings[:id] = id
        end

        def keys(ids)
          key ids
        end

        def validity_check(block)
          validator_settings[:check] = block
        end

        def error_message(message)
          validator_settings[:message] = message
        end

        def validator_settings
          @validator_settings ||= {}
        end
      end



    end
  end
end

