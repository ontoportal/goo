require_relative 'test_case'

GooTest.configure_goo
require_relative 'models'

class Person < Goo::Base::Resource
  model :person_model_validators, name_with: :name
  attribute :name, enforce: [:string, :existence]
  attribute :last_name, enforce: [:string]
  attribute :multiple_values, enforce: [ :list, :integer]
  attribute :one_number, enforce: [ :integer ]
  attribute :birth_date, enforce: [ :date_time ]
  attribute :male, enforce: [:boolean]
  attribute :social, enforce: [:uri]
  attribute :weight, enforce: [:float]
  attribute :friends, enforce: [Person, :list]
end


class RangeTestModel < Goo::Base::Resource
  model :range_test_model, name_with: :name
  attribute :name, enforce: [:string, :existence, :min_3, :max_5]
  attribute :multiple_values, enforce: [ :list, :integer, :min_3, :max_5 ]
  attribute :one_number, enforce: [ :integer,  :min_3, :max_5]
  attribute :weight, enforce: [:float, :min_3, :max_5]
end



class TestValidators < MiniTest::Unit::TestCase

  def self.before_suite
    begin
      GooTestData.create_test_case_data
    rescue Exception => e
      puts e.message
    end
  end

  def self.after_suite
    GooTestData.delete_test_case_data
  end


  def test_unique_validator

    s = Student.new
    s.birth_date = DateTime.parse('1978-01-01')

    s.name = "Susan"

    refute s.valid?

    s.name = "new"

    assert s.valid?
  end

  def test_existence_validator
    s = Student.new

    refute s.valid?

    assert s.errors[:name][:existence]
    assert s.errors[:birth_date][:existence]


    s.name = ''
    s.birth_date = ''
    assert s.errors[:name][:existence]
    assert s.errors[:birth_date][:existence]


    s.name = 'new'
    s.birth_date = DateTime.parse('1978-01-01')

    assert s.valid?
  end

  def test_datatype_validators
    p = Person.new
    p.name =  'test'
    #nil  values are valid
    assert p.valid?

    p.last_name =  false
    p.multiple_values = "hello"
    p.one_number = "hello"
    p.birth_date = 100
    p.male =  "ok"
    p.social =  100
    p.weight =  100


    #wrong types are not valid
    refute p.valid?
    assert p.errors[:last_name][:string]
    assert p.errors[:multiple_values][:list]
    assert p.errors[:multiple_values][:integer]
    assert p.errors[:one_number][:integer]
    assert p.errors[:birth_date][:date_time]
    assert p.errors[:male][:boolean]
    assert p.errors[:social][:uri]

    p.last_name =  "hello"
    p.multiple_values = [22,11]
    p.one_number = 12
    p.birth_date = DateTime.parse('1978-01-01')
    p.male =  true
    p.social =  RDF::URI.new('https://test.com/')
    p.weight =  100.0
    #good types are  valid
    assert p.valid?
  end

  def test_uri_datatype_validator
    p = Person.new
    p.name =  'test'

    assert p.valid?

    p.social =  RDF::URI.new('') #empty uri
    refute p.valid?

    p.social =  RDF::URI.new('wrong/uri')
    refute p.valid?

    p.social =  RDF::URI.new('https://test.com/')
    assert p.valid?
  end

  def test_object_type_validator
    p = Person.new
    p.name =  'test'
    p.friends = [1]

    refute p.valid?

    new_person = Person.new
    p.friends = [new_person]

    refute p.valid?

    new_person.persistent = true
    p.friends = [new_person]

    assert p.valid?
  end

  def test_value_range_validator
    p = RangeTestModel.new

    p.name =  "h"
    p.multiple_values = [22,11]
    p.one_number = 1
    p.weight = 1.1

    refute p.valid?
    assert p.errors[:name][:min]
    assert p.errors[:multiple_values][:min]
    assert p.errors[:one_number][:min]
    assert p.errors[:weight][:min]

    p.name =  "hello hello"
    p.multiple_values = [22,11,11,33,44, 55, 66]
    p.one_number = 12
    p.weight = 12.1

    refute p.valid?
    assert p.errors[:name][:max]
    assert p.errors[:multiple_values][:max]
    assert p.errors[:one_number][:max]
    assert p.errors[:weight][:max]

    p.name =  "hello"
    p.multiple_values = [22,11,11,3]
    p.one_number = 4
    p.weight = 3.1

    assert p.valid?

  end

end
