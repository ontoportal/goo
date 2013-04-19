require_relative 'test_case'

TestInit.configure_goo

#collection on attribute
class Issue < Goo::Base::Resource
  model :issue, collection: :owner 
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

  def test_collection
    john = User.find("John", include: [:name]) || User.new(name: "John").save()
    issue = Issue.find("issue1", collection: john) || Issue.new(description: "issue1", owner: john).save()
    assert !Issue.find("issue1", collection: john).nil?
    assert_raises ArgumentError do
      Issue.find("issue1")
    end
    assert issue.owner.id == john.id

    #same reference
    assert john.object_id == Issue.find("issue1",collection: john).owner.object_id
    owner = Issue.find("issue1",collection: john).owner

    assert_equal(1,
      count_pattern(
        "GRAPH #{owner.id.to_ntriples} { #{issue.id.to_ntriples} a ?x }" ))
    assert_equal(0,
      count_pattern(
        "GRAPH #{owner.id.to_ntriples} { #{issue.id.to_ntriples} #{issue.class.attribute_uri(:owner).to_ntriples} ?x }" ))

    issue.delete
    assert_equal(0,
      count_pattern(
        "GRAPH #{owner.id.to_ntriples} { #{issue.id.to_ntriples} a ?x }" ))
  end

  def test_unique_per_collection

    #exist? should use collection
    #same ids in different collections can save
    #different  
    binding.pry
  end

  def test_inverse_on_collection
    binding.pry
    User.find("John",include: issues).issues
  end

  def test_change_owner_changes_collections
    binding.pry
  end

  def test_collection_lambda
    binding.pry
  end

  def test_multiple_collection
    #something like a read only object
    #that collection: :all
    #returns an aggregation
    #it cannot be save
    #collection attribute returns multiple owners
  end

end
