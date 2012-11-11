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
end

