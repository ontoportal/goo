require_relative 'test_case'

class TestModelPersonB < TestCase
  def setup
  end

  def test_person_save
    person = Person.new({:name => "Goo Fernandez",
                         :birth_date => DateTime.parse("2012-10-04T07:00:00.000Z"),
                         :some_stuff => [1]})
    if person.exists?
      person_copy = Person.new
      person_copy.load(person.resource_id)
      person_copy.delete
    end
    assert_equal false, person.exists?(reload=true)
    person.save
    assert_equal true, person.exists?(reload=true)
    person.delete
    assert_equal false, person.exists?(reload=true)
  end

  def test_person_update_unique
    person = Person.new({:name => "Goo Fernandez",
                        :birth_date => DateTime.parse("2012-10-04T07:00:00.000Z"),
                        :some_stuff => [1]})
    if person.exists?
      person_copy = Person.new
      person_copy.load(person.resource_id)
      person_copy.delete
    end
    assert_equal false, person.exists?(reload=true)
    person.save
    begin
    person_update = Person.new()
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
    person = Person.new({:name => "Goo Fernandez",
                        :birth_date => DateTime.parse("2012-10-04T07:00:00.000Z"),
                        :some_stuff => [1]})
    if person.exists?
      person_copy = Person.new
      person_copy.load(person.resource_id)
      person_copy.delete
    end
    assert_equal false, person.exists?(reload=true)
    person.save
    person_update = Person.new()
    person_update.load(person.resource_id)
    person_update.birth_date =  DateTime.parse("2013-01-01T07:00:00.000Z")
    person_update.save
    assert_equal DateTime.parse("2013-01-01T07:00:00.000Z"), person_update.birth_date
    #reload
    person_update = Person.new()
    person_update.load(person.resource_id)
    assert_equal DateTime.parse("2013-01-01T07:00:00.000Z"), person_update.birth_date
    assert_equal "Goo Fernandez", person_update.name
    person_update.delete
    assert_equal false, person_update.exists?(reload=true)
  end
  
end

