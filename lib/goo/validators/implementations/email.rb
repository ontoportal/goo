module Goo
  module Validators
    class Email < ValidatorBase
      include Validator
      EMAIL_REGEXP = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
      key :email

      error_message ->(obj) {
        if @value.kind_of? Array
          return "All values in attribute `#{@attr}` must be a valid emails"
        else
          return "Attribute `#{@attr}` with the value `#{@value}` must be a valid email"

        end
      }

      validity_check -> (obj) do
        @value.nil? || @value.match?(EMAIL_REGEXP)
      end
    end
  end
end