require_relative 'test_case'

TestInit.configure_goo


class Status < Goo::Base::Resource
  model :status
  attribute :description, enforce: [ :existence ]

  def initialize(attributes = {})
    super(attributes)
  end
end

class Person < Goo::Base::Resource
  model :person
  attribute :name, enforce: [ :existence, :string ]
  attribute :multiple_values, enforce: [ :list, :integer, :min_3, :max_5 ]
  attribute :one_number, enforce: [ :existence, :integer ]
  attribute :birth_date, enforce: [ :existence, :date_time ]

  attribute :created, enforce: [ :existence, DateTime ],
            default: lambda { |record| DateTime.now }
            
  attribute :friends, enforce: [ :existence ]
  attribute :status, enforce: [ :existence, :status ],
  			default: lambda { |record| Status.find("single") }

  def initialize(attributes = {})
    super(attributes)
  end
end

class Test < TestCase
  def initialize(*args)
    super(*args)
  end

  def test_attributes_set_get
    person = Person.new
    assert(person.respond_to? :id)
    assert(person.kind_of? Goo::Base::Resource)
    person.name = "John"
    assert person.name == "John"
    person.name = 1
    assert person.valid?
    assert person.errors[:name]

    assert_raises ArgumentError do 
    end
    assert person.name == "John"
    assert_raises ArgumentError do 
       person.name = 1
    end
    assert_raises ArgumentError do 
      person.birth_date = "John"
    end
    person.birth_date = DateTime.parse('2001-02-03T04:05:06.12')
    assert person.birth_date == DateTime.parse('2001-02-03T04:05:06.12')

    person.multiple_values = [1, 2, 3]
    assert person.valid?
    person.multiple_values = [1, "2", "3"]
    assert_raises ArgumentError do 
    end
    assert_raises ArgumentError do 
      person.multiple_values = [1, 2]
    end
    assert_raises ArgumentError do 
      person.multiple_values = [1, 2, 3, 4, 5, 6]
    end
  end
end
