module Goo
  module Validators
    class Existence < ValidatorBase
      include Validator

      key :existence

      error_message ->(obj) { "`#{@value}` value cannot be nil"}

      validity_check -> (obj) do
        not self.class.empty_value?(@value)
      end


    end
  end
end