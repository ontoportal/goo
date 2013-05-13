require_relative '../test_case'

GooTest.configure_goo

module Test
  module Models
    class Ontology < Goo::Base::Resource
      model :ontology, namespace: :bioportal, name_with: :acronym
      attribute :acronym, namespace: :omv, enforce: [:existence, :unique]
      attribute :name, namespace: :omv, enforce: [:existence]
      attribute :administeredBy, enforce: [:list, :user, :existence]
    end 

    class User < Goo::Base::Resource
      model :user, name_with: :username
      attribute :username, enforce: [:existence, :unique]
      attribute :email, enforce: [:existence, :email]
      attribute :roles, enforce: [:list, :roles, :existence]
      attribute :created, enforce: [ DateTime ],
                default: lambda { |record| DateTime.now }
    end 

    class Role < Goo::Base::Resource
      model :role, :inmutable,  name_with: :code
      attribute :code, enforce: [:existence, :unique]
      attribute :users, inverse: { on: User, attribute: :roles }
    end

  end
end
