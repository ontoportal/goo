require_relative 'test_case'

TestInit.configure_goo

class Issue < Goo::Base::Resource
  model :issue
  attribute :description, enforce: [ :existence, :unique]
  attribute :owner, enforce: [:user]

  def initialize(attributes = {})
    super(attributes)
  end
end

class User < Goo::Base::Resource
  model :user
  attribute :name, enforce: [ :existence, :unique ]
  attribute :issues, inverse: { on: Issue, attribute: :owner }
end

class TestCollection < TestCase
  def initialize(*args)
    super(*args)
  end

  def test_unique_per_collection
    binding.pry
  end

  def test_inverse_on_collection
    binding.pry
    User.find("John",include: issues).issues
  end

end
