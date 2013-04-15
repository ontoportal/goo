require_relative 'test_case'

TestInit.configure_goo


class Status < Goo::Base::Resource
  model :status
  attribute :description, enforce: [ :existence, :unique]
  attribute :active, enforce: [ :existence, :boolean ], namespace: :omv

  def initialize(attributes = {})
    super(attributes)
  end
end

class Person < Goo::Base::Resource
  model :person
  attribute :name, enforce: [ :existence, :string, :unique]
  attribute :multiple_values, enforce: [ :list, :existence, :integer, :min_3, :max_5 ]
  attribute :one_number, enforce: [ :existence, :integer ] #by default not a list
  attribute :birth_date, enforce: [ :existence, :date_time ]

  attribute :created, enforce: [ DateTime ],
            default: lambda { |record| DateTime.now },
            namespace: :omv
            
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

  def test_default_value
    #default is on save ... returns`
    binding.pry
  end

  def test_simple_save_delete
    st = Status.new(description: "some text", active: true)
    assert_equal("some text", st.description)
    st = Status.new({ description: "some text", active: true })
    assert_equal("some text", st.description)
    assert st.valid?
    assert !st.persistent?
    assert st.modified?
    assert !st.exist?
    assert st == st.save 
    assert st.persistent?
    assert !st.modified?
    assert nil == st.delete
    assert !st.exist?
    assert !st.persistent?
    assert !st.modified?
  end

  def test_not_valid_save
    st = Status.new({ description: "some text", active: "true" })
    assert_raises Goo::Base::NotValidException do
      st.save
    end
    assert !st.persistent?
  end

  def test_find
    st = Status.new({ description: "some text", active: true })
    st.save
    assert st.persistent?
    
    id = st.id
    st_from_backend = Status.find(id)
    assert_instance_of Status, st_from_backend
    assert (st_from_backend.kind_of? Goo::Base::Resource)
    assert_equal id, st_from_backend.id

    st.class.attributes.each do |attr|
      assert_raises Goo::Base::AttributeNotLoaded do
        st_from_backend.send("#{attr}")
      end
    end

    assert st_from_backend.persistent?
    assert !st_from_backend.modified?

    assert nil == st_from_backend.delete
    assert !st_from_backend.exist?

    not_existent_id = RDF::URI("http://some.bogus.id/x")
    st_from_backend = Status.find(not_existent_id)
    assert st_from_backend.nil?
  end

  def test_find_load_all
    st = Status.new({ description: "some text", active: true })
    st.save
    assert st.persistent?
    
    id = st.id
    st_from_backend = Status.find(id, include: Status.attributes )
    assert (st_from_backend.persistent?)
    assert (!st_from_backend.modified?)

    st.class.attributes.each do |attr|
      assert_equal(st.send("#{attr}"), st_from_backend.send("#{attr}"))
    end

    assert nil == st_from_backend.delete
    assert !st_from_backend.exist?
  end

  def test_update_array_values
    #object should always return freezed arrays
    #so that we detect the set
    binding.pry
  end

end
