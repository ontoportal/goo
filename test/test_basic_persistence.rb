require_relative 'test_case'

TestInit.configure_goo


class ArrayValues < Goo::Base::Resource
  model :array_values
  attribute :name, enforce: [ :existence, :unique ]
  attribute :many, enforce: [ :list, :string ]
end

class StatusPersistent < Goo::Base::Resource
  model :status
  attribute :description, enforce: [ :existence, :unique]
  attribute :active, enforce: [ :existence, :boolean ], namespace: :omv

  def initialize(attributes = {})
    super(attributes)
  end
end

class PersonPersistent < Goo::Base::Resource
  model :person
  attribute :name, enforce: [ :existence, :string, :unique]
  attribute :multiple_values, enforce: [ :list, :existence, :integer, :min_3, :max_5 ]
  attribute :one_number, enforce: [ :existence, :integer ] #by default not a list
  attribute :birth_date, enforce: [ :existence, :date_time ]

  attribute :created, enforce: [ DateTime ],
            default: lambda { |record| DateTime.now },
            namespace: :omv
            
  attribute :friends, enforce: [ PersonPersistent ]
  attribute :status, enforce: [ :status ],
  			default: lambda { |record| StatusPersistent.find("single") }

  def initialize(attributes = {})
    super(attributes)
  end
end

class TestBasicPersistence < TestCase
  def initialize(*args)
    super(*args)
  end


  def test_simple_save_delete
    st = StatusPersistent.new(description: "some text", active: true)
    assert_equal("some text", st.description)
    st = StatusPersistent.new({ description: "some text", active: true })
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
    st = StatusPersistent.new({ description: "some text", active: "true" })
    assert_raises Goo::Base::NotValidException do
      st.save
    end
    assert !st.persistent?
  end

  def test_find
    st = StatusPersistent.new({ description: "some text", active: true })
    st.save
    assert st.persistent?
    
    id = st.id
    st_from_backend = StatusPersistent.find(id)
    assert_instance_of StatusPersistent, st_from_backend
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
    st_from_backend = StatusPersistent.find(not_existent_id)
    assert st_from_backend.nil?
  end

  def test_find_load_all
    st = StatusPersistent.new({ description: "some text", active: true })
    st.save
    assert st.persistent?
    
    id = st.id
    st_from_backend = StatusPersistent.find(id, include: StatusPersistent.attributes )
    assert (st_from_backend.persistent?)
    assert (!st_from_backend.modified?)

    st.class.attributes.each do |attr|
      assert_equal(st.send("#{attr}"), st_from_backend.send("#{attr}"))
    end
    assert st_from_backend.fully_loaded?
    assert (st_from_backend.missing_load_attributes.length == 0)

    assert nil == st_from_backend.delete
    assert !st_from_backend.exist?
  end

  def test_find_load_some
    st = StatusPersistent.new({ description: "some text", active: true })
    st.save
    assert st.persistent?
    
    id = st.id
    st_from_backend = StatusPersistent.find(id, include: [ :active ] )
    assert (st_from_backend.persistent?)
    assert (!st_from_backend.modified?)

    assert (st_from_backend.active == true)
    assert_raises Goo::Base::AttributeNotLoaded do
      st_from_backend.description
    end

    assert !st_from_backend.fully_loaded?
    assert (st_from_backend.missing_load_attributes.length == 1)
    assert (st_from_backend.missing_load_attributes.include?(:description))

    assert nil == st_from_backend.delete
    assert !st_from_backend.exist?
  end

  def test_update_unique
    #fail when updating a unique field
    binding.pry
  end

  def test_find_with_string
    st = StatusPersistent.new({ description: "some text", active: true })
    st.save
    assert st.persistent?
    st_from_backend = StatusPersistent.find("some text", include: [ :active ] )
    assert_instance_of(StatusPersistent, st_from_backend)
    assert_equal(st.id, st_from_backend.id)
    assert_equal(true, st_from_backend.active)
    st_from_backend.delete

    st_from_backend = StatusPersistent.find("not there")
    assert st_from_backend.nil?
  end

  def test_update
    st = StatusPersistent.new({ description: "some text", active: true })
    st.save
    assert st.persistent?

    st.active = false
    assert(st.modified?)
    st.save
    assert(!st.modified?)

    st_from_backend = StatusPersistent.find(st.id, include: [ :active ] )
    assert (st_from_backend.persistent?)
    assert !st_from_backend.modified?
    assert_equal(false, st_from_backend.active)

    assert nil == st_from_backend.delete
    assert !st_from_backend.exist?
  end

  def test_update_array_values
    #object should always return freezed arrays
    #so that we detect the set
    arr = ArrayValues.new(name: "x" , many: ["a","b"])
    assert (arr.valid?)
    arr.save
    assert arr.persistent?
    assert arr.exist?

    arr_from_backend = ArrayValues.find(arr.id, include: ArrayValues.attributes)
    assert_equal ["a", "b"], arr_from_backend.many.sort

    assert_raises RuntimeError do
      arr_from_backend.many << "c"
    end

    arr_from_backend.many = ["A","B","C"]
    arr_from_backend.save

    arr_from_backend = ArrayValues.find(arr.id, include: ArrayValues.attributes)
    assert_equal ["A","B","C"], arr_from_backend.many.sort

    arr_from_backend.delete
    assert !arr_from_backend.exist?

  end

  def test_person_save
    st = StatusPersistent.new(description: "single", active: true)
    st.save

    person = PersonPersistent.new
    person.name = "John"
    person.multiple_values = [1,2,3,4]
    person.one_number = 99
    person.birth_date = DateTime.parse('2001-02-03T04:05:06.12')
    assert person.valid?
    person.save
    assert person.persistent?
    assert !person.modified?

    assert_equal nil, person.friends

    #default st and created
    assert_instance_of(StatusPersistent, person.status)
    assert_instance_of(DateTime, person.created)
    assert_equal(nil, person.friends)

    person_from_backend = PersonPersistent.find("John", include: PersonPersistent.attributes)
    binding.pry
    assert_equal(person.status.id, person_from_backend.status)
    assert_equal(nil, person_from_backend.friends)
    assert_equal(person.name, person_from_backend.name)
    assert_equal(person.multiple_values.sort, person_from_backend.multiple_values.sort)
    assert_equal(person.birth_date, person_from_backend.birth_date)
    assert_equal(person.created, person_from_backend.created)

    person_from_backend.delete
    assert !person_from_backend.exist?
  end

end

