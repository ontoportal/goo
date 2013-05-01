require_relative 'test_case'

GooTest.configure_goo


class ArrayValues < Goo::Base::Resource
  model :array_values, name_with: :name
  attribute :name, enforce: [ :existence, :unique ]
  attribute :many, enforce: [ :list, :string ]
end

class StatusPersistent < Goo::Base::Resource
  model :status_persistent, name_with: :description
  attribute :description, enforce: [ :existence, :unique]
  attribute :active, enforce: [ :existence, :boolean ], namespace: :omv
  attribute :code, enforce: [:unique]

  def initialize(attributes = {})
    super(attributes)
  end
end

class PersonPersistent < Goo::Base::Resource
  model :person_persistent, name_with: :name
  attribute :name, enforce: [ :existence, :string, :unique]
  attribute :multiple_values, enforce: [ :list, :existence, :integer, :min_3, :max_5 ]
  attribute :one_number, enforce: [ :existence, :integer ] #by default not a list
  attribute :birth_date, enforce: [ :existence, :date_time ]

  attribute :created, enforce: [ DateTime ],
            default: lambda { |record| DateTime.now },
            namespace: :omv
            
  attribute :friends, enforce: [ :list, PersonPersistent ]
  attribute :status, enforce: [ :status_persistent ],
  			default: lambda { |record| StatusPersistent.find("single") }

  def initialize(attributes = {})
    super(attributes)
  end
end

class TestBasicPersistence < MiniTest::Unit::TestCase
  def initialize(*args)
    super(*args)
  end

  def _purge
    objects = [ArrayValues, PersonPersistent, StatusPersistent]
    objects.each do |obj|
      obj.all.each do |st|
        st.delete
      end
    end
  end

  def setup
    _purge
  end

  def teardown
    _purge
  end

  def test_simple_save_delete
    st = StatusPersistent.new(description: "some text", active: true)
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

  def test_unique_duplicates_error
    StatusPersistent.all.each do |st|
      st.delete
    end
    st = StatusPersistent.new(description: "some text", active: true)
    assert st.valid?
    st.save
    st = StatusPersistent.new(description: "some text", active: true)
    assert !st.valid?
    assert_instance_of String, st.errors[:description][:duplicate]
    st = StatusPersistent.new(description: "some text 2", active: true)
    assert st.valid?
    st.save
    StatusPersistent.all.each do |st|
      st.delete
    end
  end

  def test_multiple_unique_attributes
    st = StatusPersistent.new(description: "some text", active: true, code: "001")
    assert st.valid?
    st.save

    #same object but new. We cannot a save duplicate id.
    #code should not contains errors because we cannot tell apart the resources.
    st = StatusPersistent.new(description: "some text", active: true, code: "001")
    assert !st.valid?
    assert_instance_of String, st.errors[:description][:duplicate]
    assert nil == st.errors[:code]

    #here a differente description therefore a different resource.
    #code should contain a duplication error.
    st = StatusPersistent.new(description: "some text 2", active: true, code: "001")
    assert !st.valid?
    assert_instance_of String, st.errors[:code][:unique]

    st = StatusPersistent.new(description: "some text 2", active: true, code: "002")
    assert st.valid?
    st.save
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
    assert (st_from_backend.missing_load_attributes.length == 2)
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
    st = st.exist? ? StatusPersistent.find("single") : st.save

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
    assert_equal(person.status.id, person_from_backend.status.id)
    assert_equal(nil, person_from_backend.friends)
    assert_equal(person.name, person_from_backend.name)
    assert_equal(person.multiple_values.sort, person_from_backend.multiple_values.sort)
    assert_equal(person.birth_date.xmlschema, person_from_backend.birth_date.xmlschema)
    assert_equal(person.created.xmlschema, person_from_backend.created.xmlschema)

    person_from_backend.delete
    assert !person_from_backend.exist?
    st.delete
  end

  def test_friends
    st = StatusPersistent.new(description: "single", active: true)
    st = st.exist? ? StatusPersistent.find("single") : st.save
    person1 = PersonPersistent.new(name: "John", multiple_values: [1,2,3,4], one_number: 99,
                                   birth_date: DateTime.parse('2001-02-03T04:05:06.12'))

    person2 = PersonPersistent.new(name: "Rick", multiple_values: [1,2,3,4], one_number: 99,
                               birth_date: DateTime.parse('2001-02-03T04:05:06.12'))
    person2.friends = [person1]

    #dependent objects must be persistant
    assert !person2.valid?
    assert person2.errors[:friends][:person_persistent]

    person1.save

    assert person2.valid?
    person2.save

    from_backend = PersonPersistent.find(person2.id, include: [:friends])
    assert_equal 1, person2.friends.length
    assert_equal person1.id, person2.friends.first.id


    person1.delete
    assert 0, GooTest.triples_for_subject(person1.id)
    person2.delete
    assert 0, GooTest.triples_for_subject(person2.id)
  end

end

