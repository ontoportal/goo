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
  attribute :multiple_values, enforce: [ :list, :existence, :integer, :min_3, :max_5 ]
  attribute :one_number, enforce: [ :existence, :integer ] #by default not a list
  attribute :birth_date, enforce: [ :existence, :date_time ]

  attribute :created, enforce: [ DateTime ],
            default: lambda { |record| DateTime.now }
            
  attribute :friends, enforce: [ :existence , Person]
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
    assert !person.valid?

    assert person.errors[:name][:existence]
    assert person.errors[:friends][:existence]
    assert person.errors[:status][:existence]
    assert person.errors[:birth_date][:existence]
    assert person.errors[:one_number][:existence]
    assert !person.errors[:created]

    person.name = "John"
    assert !person.valid?
    assert !person.errors[:name]

    person.name = 1
    assert_equal 1, person.name
    assert !person.valid?
    assert person.errors[:name][:string]
    person.name = "John"

    assert_equal("John", person.name)


    person.birth_date = DateTime.parse('2001-02-03T04:05:06.12')
    assert !person.valid?
    assert !person.errors[:birth_date]

    person.birth_date = "X" 
    assert !person.valid?
    assert person.errors[:birth_date][:date_time]

    person.birth_date = DateTime.parse('2001-02-03T04:05:06.12')
    assert_equal(DateTime.parse('2001-02-03T04:05:06.12'), person.birth_date)
    assert !person.valid?
    assert !person.errors[:birth_date]


    person.multiple_values = [1, 2, 3, 4]
    assert !person.valid?
    assert !person.errors[:multiple_values]

    person.multiple_values = [1, 2]
    assert !person.valid?
    assert person.errors[:multiple_values][:min]

    person.multiple_values = [1, 2, 3, 4, 5, 6]
    assert !person.valid?
    assert person.errors[:multiple_values][:max]


    person.multiple_values = [1, 2, 3, "4", 5, 6]
    assert !person.valid?
    assert person.errors[:multiple_values][:max]
    assert person.errors[:multiple_values][:integer]

    person.multiple_values = [1, 2, 3, 4]
    assert !person.valid?
    assert !person.errors[:multiple_values]

    friends = [Person.new , Person.new]
    person.friends = friends
    assert !person.valid?
    assert person.errors[:friends][:no_list]
    person.friends = Person.new
    assert !person.valid?
    assert !person.errors[:friends]
    person.friends = "some one"
    assert !person.valid?
    assert person.errors[:friends][:person]
    person.friends = Person.new

    person.one_number = 99
    assert !person.valid?
    assert !person.errors[:one_number]

    person.one_number = "99"
    assert !person.valid?
    assert person.errors[:one_number][:integer]

    person.one_number = [98, 99]
    assert !person.valid?
    assert person.errors[:one_number][:no_list]

    person.one_number = 99 
    assert_equal(99, person.one_number)
    assert !person.valid?
    assert !person.errors[:one_number]

    assert person.errors[:status][:existence]
    person.status = Status.new
    assert person.valid?
  end

  def test_simple_save
    st = Status.new(description: "some text")
    assert_equal("some text", st.description)
    st = Status.new({ description: "some text" })
    assert_equal("some text", st.description)
    assert st.valid?
    assert !st.persistent?
    assert st.modified?
  end

end
