require_relative 'test_case'

class Person < Goo::Base::Resource
  model :person
  validates :name, :presence => true, :cardinality => { :maximum => 1 }
  validates :multiple_vals, :cardinality => { :maximum => 2 }
  validates :birth_date, :date_time_xsd => true, :presence => true, :cardinality => { :maximum => 1 }
  unique :name
  graph_policy :type_id_graph_policy

  def initialize(attributes = {})
    super(attributes)
  end
end

class TestModelPersonA < TestCase
  def setup
  end

  def test_person
    person = Person.new({:name => "Goo Fernandez", :birth_date => DateTime.parse("2012-10-04T07:00:00.000Z"), :some_stuff => [1]})
    assert_instance_of Hash, person.class.goop_settings
    assert_equal :person, person.class.goop_settings[:model]
    assert_equal "Goo Fernandez", person.name
    assert_equal [1], person.some_stuff 
    assert_equal DateTime.parse("2012-10-04T07:00:00.000Z"), person.birth_date
    assert_equal true, person.valid?
  end
  
  def test_cardinality
    person = Person.new({:name => "Goo Fernandez", :birth_date => DateTime.parse("2012-10-04T07:00:00.000Z"), :some_stuff => [1]})
    person.multiple_vals= 1 
    person.multiple_vals << 2 
    assert_equal true, person.valid?
    person.multiple_vals << 3 
    assert_equal [1,2,3], person.multiple_vals
    assert_equal false, person.valid?
    assert_instance_of String, person.errors[:multiple_vals][0]
  end

  def test_valid_date
    person = Person.new({:name => "Goo Fernandez", :birth_date => "xxxx", :some_stuff => [1]})
    assert_equal false, person.valid?
    assert_instance_of String, person.errors[:birth_date][0]
  end

  def test_person_modify
    person = Person.new({:name => "Goo Fernandez", :some_stuff => [1]})
    person.name= "changed named"
    assert_equal "changed named", person.name
    begin 
      #cardinality error
      person.name= ["a","b"]
      #unreachable
      assert_equal 1, 0 
    rescue => e
      assert_instance_of ArgumentError, e
    end
    person.some_stuff[0] = 2
    assert_equal [2], person.some_stuff
    person.some_stuff << 123
    assert_equal [2, 123], person.some_stuff
    person.some_stuff= []
    assert_equal [], person.some_stuff 
  end

  def test_person_multiple_unique_error
    begin
      person = Person.new({:name => ["Goo Fernandez", "Value2]"] })
    rescue => e
      assert_instance_of ArgumentError, e 
    end
  end

  def test_person_unique_for_multiple_error
    begin
      person = Person.new({:name => "Unique", :some => 1 })
    rescue => e
      assert_instance_of ArgumentError, e 
    end
  end
end
