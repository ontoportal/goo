require_relative 'test_case'


class ToyObject < Goo::Base::Resource
  model :toyobject
  validates :prop, :presence => true, :cardinality => { :maximum => 1 }
  unique :prop

  def initialize(attributes = {})
    super(attributes)
  end

end

class TestModelSearch < TestCase

  def initialize(*args)
    super(*args)
    voc = Goo::Naming.get_vocabularies
    if not voc.is_type_registered? :toyobject
      voc.register_model(:foaf, :toyobject , ToyObject)
    else
      raise StandarError, "Error conf unit test" if :toyobject != voc.get_model_registry(ToyObject)[:type]
    end
  end
  
  def create_toys(max)
    (0..max-1).each do |n|
      toy = ToyObject.new
      toy.prop = "some value for #{n}"
      if n % 2 == 0
        toy.prop_even = n
        toy.prop_x = "x"
      else
        toy.prop_odd = n
      end
      if toy.exist?
        toy_copy = ToyObject.new
        toy_copy.load(toy.resource_id)
        toy_copy.delete
      end
      assert_equal false, toy.exist?(reload=true)
      toy.save
      assert_equal true, toy.exist?(reload=true)
      assert_equal 1, count_pattern("#{toy.resource_id.to_turtle} a ?type .")
    end
  end

  def test_search_simple
    max = 10
    create_toys(max)

    #get them all
    toys = ToyObject.search({})
    assert_equal 10, toys.length
    lits = Set.new
    toys.each do |t|
      t.load
      lits << t.prop
    end
    (0..max-1).each do |n|
      assert_equal true, (lits.include? "some value for #{n}")
    end
    toys = ToyObject.search({:prop_x => "x" })
    assert_equal max/2, toys.length
    toys.each do |t|
      t.load
      assert_instance_of Fixnum, t.prop_even[0]
      assert_equal 0, t.prop_even[0] % 2
    end
    toys = ToyObject.search({})
    toys.each do |t|
      t.load
      t.delete
    end
    toys = ToyObject.search({})
    assert_equal 0, toys.length
  end

end


