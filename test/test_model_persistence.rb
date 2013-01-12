require_relative 'test_case'

TestInit.configure_goo

class StatusPersist < Goo::Base::Resource
  model :status
  attribute :description, :unique => true

  def initialize(attributes = {})
    super(attributes)
  end
end

class PersonPersist < Goo::Base::Resource
  attribute :name, :unique => true
  attribute :multiple_vals, :cardinality => { :maximum => 2 }
  attribute :birth_date, :date_time_xsd => true, :cardinality => { :max => 1, :min => 1  }
  attribute :created, :date_time_xsd => true, :single_value=> true, :default => lambda { |record| DateTime.now }
  attribute :friends, :not_nil => false

  def initialize(attributes = {})
    super(attributes)
  end
end

class University < Goo::Base::Resource
  attribute :name, :unique => true
  attribute :location,  :instance_of => { :with => :location }
  attribute :students,  :instance_of => { :with => :person_persist }
  attribute :status,  :instance_of => { :with => :status }
  attribute :iri_value, :instance_of => { :with => RDF::IRI }, :single_value  => true
end

class Location < Goo::Base::Resource
end

class TestModelPersonPersistB < TestCase

  def initialize(*args)
    super(*args)
 end

  def test_person_save
    data = PersonPersist.all
    data.each do |p|
      p.load
      p.delete
    end
    person = PersonPersist.new({:name => "Goo Fernandez",
                         :birth_date => DateTime.parse("2012-10-04T07:00:00.000Z"),
                         :some_stuff => [1]})
    assert (person.valid?)
    assert_equal false, person.exist?(reload=true)
    person.save
    assert_equal true, person.exist?(reload=true)
    person.delete
    assert_equal false, person.exist?(reload=true)
    no_triples_for_subject(person.resource_id)
  end

  def test_person_update_unique
    person = PersonPersist.new({:name => "Goo Fernandez",
                        :birth_date => DateTime.parse("2012-10-04T07:00:00.000Z"),
                        :some_stuff => [1]})
    if person.exist?
      person_copy = PersonPersist.new
      person_copy.load(person.resource_id)
      person_copy.delete
    end
    assert_equal false, person.exist?(reload=true)
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
    assert_equal false, person_update.exist?(reload=true)
  end

  def test_person_update_date
    person = PersonPersist.new({:name => "Goo Fernandez",
                        :birth_date => DateTime.parse("2012-10-04T07:00:00.000Z"),
                        :some_stuff => [1]})
    if person.exist?
      person_copy = PersonPersist.new
      person_copy.load(person.resource_id)
      person_copy.delete
    end
    assert_equal false, person.exist?(reload=true)
    person.save
    person_update = PersonPersist.new()
    person_update.load(person.resource_id)

    #default value is there
    created_time = person_update.created
    assert_instance_of DateTime, created_time

    #update field
    person_update.birth_date =  DateTime.parse("2013-01-01T07:00:00.000Z")

    person_update.save
    assert_equal 1, count_pattern("#{person_update.resource_id.to_turtle} a ?type .")
    assert_equal DateTime.parse("2013-01-01T07:00:00.000Z"), person_update.birth_date
    #reload
    person_update = PersonPersist.new()
    person_update.load(person.resource_id)
    assert_equal DateTime.parse("2013-01-01T07:00:00.000Z"), person_update.birth_date
    assert_equal "Goo Fernandez", person_update.name

    #making sure default values do not change in an update
    assert_equal created_time.xmlschema, person_update.created.xmlschema

    person_update.delete
    assert_equal false, person_update.exist?(reload=true)
    assert_equal 0, count_pattern("#{person_update.resource_id.to_turtle} a ?type .")
  end

  def test_person_add_remove_property
    person = PersonPersist.new({:name => "Goo Fernandez",
                        :birth_date => DateTime.parse("2012-10-04T07:00:00.000Z"),
                        :some_stuff => [1]})
    if person.exist?
      person_copy = PersonPersist.new
      person_copy.load(person.resource_id)
      person_copy.delete
    end
    assert_equal false, person.exist?(reload=true)
    person.save
    person_update = PersonPersist.new()
    person_update.load(person.resource_id)
    person_update.some_date =  DateTime.parse("2013-01-01T07:00:00.000Z")
    assert_equal true, person_update.valid?
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
    assert_equal false, person_update.exist?(reload=true)
    no_triples_for_subject(person_update.resource_id)
  end

  def test_static_load
    person = PersonPersist.new({:name => "Goo Fernandez",
                        :birth_date => DateTime.parse("2012-10-04T07:00:00.000Z"),
                        :some_stuff => [1]})
    if person.exist?
      person_copy = PersonPersist.new
      person_copy.load(person.resource_id)
      person_copy.delete
    end
    assert_equal false, person.exist?(reload=true)
    person.save
    assert_equal true, person.exist?(reload=true)
    resource_id = person.resource_id

    #static load
    item = Goo::Base::Resource.load(resource_id)
    assert_instance_of person.class, item
    assert_equal person.resource_id.value, item.resource_id.value
    assert_equal person.name, item.name
    person.delete
    assert_equal false, item.exist?(reload=true)

    item = Goo::Base::Resource.load(resource_id)
    assert_equal nil, item
  end

  def test_person_dependent_persisted
    statuses = {}
    ["single","married","divorced"].each do |st|
      st_obj = StatusPersist.new({:description => st })
      if st_obj.exist?
        st_obj = Goo::Base::Resource.load(st_obj.resource_id)
      else
        st_obj.save
      end
      statuses[st] = st_obj
    end
    person = PersonPersist.new({:name => "Goo Fernandez",
                        :birth_date => DateTime.parse("2012-10-04T07:00:00.000Z"),
                        :status => [statuses["married"]] },
                         )
    if person.exist?
      person_copy = PersonPersist.new
      person_copy.load(person.resource_id)
      person_copy.delete
      assert_equal 1, count_pattern("#{statuses["married"].resource_id.to_turtle} a ?type .")
    end
    assert_equal false, person.exist?(reload=true)
    person.save
    assert_equal 1, count_pattern("#{statuses["married"].resource_id.to_turtle} a ?type .")
    person.delete
    assert_equal 1, count_pattern("#{statuses["married"].resource_id.to_turtle} a ?type .")
    assert_equal 0, count_pattern("#{person.resource_id.to_turtle} a ?type .")
    sts = StatusPersist.where({})
    sts.each do |t|
      t.load
      rid = t.resource_id
      t.delete
      assert_equal 0, count_pattern("#{rid.to_turtle} a ?type .")
    end
  end

  def test_model_by_def_name
    cls = Goo.find_model_by_name(:person_persist)
    assert (cls == PersonPersist)
    cls = Goo.find_model_by_name(:status)
    assert (cls == StatusPersist)
  end

  def test_instance_of_with_model_definitions
    University.all.each do |u|
      u.load
      u.delete
    end
    PersonPersist.all.each do |u|
      u.load
      u.delete
    end
    person = PersonPersist.new({:name => "Goo Fernandez",
                         :birth_date => DateTime.parse("2012-10-04T07:00:00.000Z"),
                         :some_stuff => [1]})
    u = University.new
    assert(!u.valid?)
    u.name = "Stanford"
    u.students = [person]
    u.status = StatusPersist.new({:description => "OK" })
    assert(u.valid?)
    u.status = 10
    u.students = ["aaa"]
    assert(!u.valid?)
    u.students = [person]
    u.iri_value = RDF::IRI.new("http://some.org/iri")
    u.status = StatusPersist.new({:description => "OK" })
    assert(u.valid?)
    u.save
    u.xxxx = "xxxx"
    assert(u.valid?)
    u.save
    u = University.find("Stanford")
    assert (not u.nil?)
    models = [University, PersonPersist, StatusPersist]
    models.each do |m|
      m.all.each do |i|
        i.load
        i.delete
      end
    end
  end

  def test_exception_on_get_lazy_load
    person = PersonPersist.new({:name => "Goo Fernandez",
                        :birth_date => DateTime.parse("2012-10-04T07:00:00.000Z"),
                        :some_stuff => [1]})
    if person.exist?
      person_copy = PersonPersist.new
      person_copy.load(person.resource_id)
      person_copy.delete
    end
    assert_equal false, person.exist?(reload=true)
    person.save

    PersonPersist.all.each do |p|
      begin
        x = p.name
        assert(1 == 0, "Attribute exception missing on lazy load")
      rescue => e
        assert_instance_of Goo::Base::NotLoadedResourceError, e
      end
      begin
        p.name= "aaa"
        assert(1 == 0, "Attribute exception missing on lazy load")
      rescue => e
        assert_instance_of Goo::Base::NotLoadedResourceError, e
      end
      p.load
      assert_instance_of(String, p.name)
    end
    PersonPersist.all.each do |p|
      p.delete
    end
  end

  def test_list_university_load_attrs
    University.all.each do |u|
      u.load
      u.delete
    end

    locs = [ ["California", "US"], ["Boston", "US"], ["Oxford", "UK"] , ["Cambridge","UK"] ,["Soton","UK"] ]
    unis = ["Stanford", "Harvard", "Oxford", "Cambridge", "Southampton"]
    unis.each_index do |i|
      u = University.new(:name => unis[i], :location => Location.new(:state =>  locs[i][0], :country => locs[i][1]))
      if (i == 0) or (i == 3)
        u.status = StatusPersist.new(:description => "description for status")
      end
      if (i == 2)
        u.bogus = "bla"
      end
      u.save
    end

    #test with no nested attr
    data = University.all :load_attrs => [:name => true, :bogus => :optional]
    assert_equal 5, data.length
    data.each do |u|
      correct = ((!u.bogus.nil? and (u.name == "Oxford")) or (u.name != "Oxford"))
      assert(correct)
    end
    begin
      data[0].status
      assert(1==0, "exception should be thrown here. not a loaded attr")
    rescue => e
      assert_instance_of Goo::Base::NotLoadedResourceError, e
    end

    data = University.all :load_attrs => [:name => true]
    assert_equal 5, data.length
    data.each do |u|
      assert ((unis.index u.name) != nil)
    end

    data = University.all :load_attrs => [:name => true, :bogus => true]
    assert_equal 1, data.length
    u = data[0]
    correct = (!u.bogus.nil? and (u.name == "Oxford"))
    assert correct

    data.each do |u|
      assert ((unis.index u.name) != nil)
    end

    data = University.where :name => "Oxford", :load_attrs => [:bogus => true]
    assert_equal 1, data.length
    assert_equal "bla", data[0].bogus

    data = University.where :name => "Oxford", :load_attrs => [:name => true]
    assert_equal 1, data.length
    assert_equal "Oxford", data[0].name



    University.all.each do |u|
      u.load
      u.delete
    end
  end

end
