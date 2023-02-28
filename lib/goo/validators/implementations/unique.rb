module Goo
  module Validators
    class Unique < ValidatorBase
      include Validator

      key :unique

      error_message ->(obj) { "`#{@attr}` must be unique. " +
        "There are other model instances with the same attribute value `#{@value}`."}

      validity_check -> (obj) do
        return true if @value.nil?

        !Goo::SPARQL::Queries.duplicate_attribute_value?(@inst,@attr)
      end


    end
  end
end