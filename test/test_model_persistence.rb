require_relative 'test_case'

class PersonPersist < Goo::Base::Resource
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

class TestModelPersonPersistB < TestCase

  def initialize(*args)
    super(*args)
    voc = Goo::Naming.get_vocabularies
    if not voc.is_type_registered? :personp
      voc.register_model(:foaf, :personp, PersonPersist)
    else
      raise StandarError, "Error conf unit test" if :personp != voc.get_model_registry(PersonPersist)[:type]
    end
  end

  def test_person_save
    person = PersonPersist.new({:name => "Goo Fernandez",
                         :birth_date => DateTime.parse("2012-10-04T07:00:00.000Z"),
                         :some_stuff => [1]})
    if person.exists?
      person_copy = PersonPersist.new
      person_copy.load(person.resource_id)
      person_copy.delete
    end
    assert_equal false, person.exists?(reload=true)
    person.save
    assert_equal true, person.exists?(reload=true)
    person.delete
    assert_equal false, person.exists?(reload=true)
    no_triples_for_subject(person.resource_id)
  end

  def test_person_update_unique
    person = PersonPersist.new({:name => "Goo Fernandez",
                        :birth_date => DateTime.parse("2012-10-04T07:00:00.000Z"),
                        :some_stuff => [1]})
    if person.exists?
      person_copy = PersonPersist.new
      person_copy.load(person.resource_id)
      person_copy.delete
    end
    assert_equal false, person.exists?(reload=true)
    person.save
    begin
    person_update = PersonPersist.new()
    person_update.load(person.resource_id)
    person_update.name = "changed name"
    #unreachable
    assert_equal 1, 0
    rescue => e
      assert_instance_of Goo::Base::KeyFieldUpdateError, e
    end
    person_update.delete
    assert_equal false, person_update.exists?(reload=true)
  end

  def test_person_update_date
    person = PersonPersist.new({:name => "Goo Fernandez",
                        :birth_date => DateTime.parse("2012-10-04T07:00:00.000Z"),
                        :some_stuff => [1]})
    if person.exists?
      person_copy = PersonPersist.new
      person_copy.load(person.resource_id)
      person_copy.delete
    end
    assert_equal false, person.exists?(reload=true)
    person.save
    person_update = PersonPersist.new()
    person_update.load(person.resource_id)
    person_update.birth_date =  DateTime.parse("2013-01-01T07:00:00.000Z")
    person_update.save
    assert_equal 1, count_pattern("#{person_update.resource_id.to_turtle} a ?type .")
    assert_equal DateTime.parse("2013-01-01T07:00:00.000Z"), person_update.birth_date
    #reload
    person_update = PersonPersist.new()
    person_update.load(person.resource_id)
    assert_equal DateTime.parse("2013-01-01T07:00:00.000Z"), person_update.birth_date
    assert_equal "Goo Fernandez", person_update.name

    person_update.delete
    assert_equal false, person_update.exists?(reload=true)
    assert_equal 0, count_pattern("#{person_update.resource_id.to_turtle} a ?type .")
  end

  def test_person_add_remove_property
    person = PersonPersist.new({:name => "Goo Fernandez",
                        :birth_date => DateTime.parse("2012-10-04T07:00:00.000Z"),
                        :some_stuff => [1]})
    if person.exists?
      person_copy = PersonPersist.new
      person_copy.load(person.resource_id)
      person_copy.delete
    end
    assert_equal false, person.exists?(reload=true)
    person.save
    person_update = PersonPersist.new()
    person_update.load(person.resource_id)
    person_update.some_date =  DateTime.parse("2013-01-01T07:00:00.000Z")
    person_update.save
    #reload
    person_update = PersonPersist.new()
    person_update.load(person.resource_id)
    assert_equal [DateTime.parse("2013-01-01T07:00:00.000Z")], person_update.some_date
    #equivalent to remove
    person_update.some_date = []
    person_update.save
    person_update = PersonPersist.new()
    person_update.load(person.resource_id)
    assert_equal nil, person_update.some_date
    person_update.delete
    assert_equal false, person_update.exists?(reload=true)
    no_triples_for_subject(person_update.resource_id)
  end
  
end

