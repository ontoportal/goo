require_relative 'test_case'

TestInit.configure_goo


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
            
  attribute :friends, enforce: [ :existence , PersonPersistent]
  attribute :status, enforce: [ :existence, :status ],
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



  def test_update_array_values
    #object should always return freezed arrays
    #so that we detect the set
    binding.pry
  end

end

