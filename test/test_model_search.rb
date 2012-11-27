require_relative 'test_case'

class Color < Goo::Base::Resource
  model :color
  validates :code, :cardinality => { :maximum => 1 }
  unique :code

  def initialize(attributes = {})
    super(attributes)
  end
end

class ToyFeature < Goo::Base::Resource
  model :toy_feature
  validates :color,  :instance_of => { :with => :color }
  validates :description, :presence => true, :cardinality => { :maximum => 1 }

  def initialize(attributes = {})
    super(attributes)
  end
end

class ToyPart < Goo::Base::Resource
  model :toy_part
  validates :feature,  :instance_of => { :with => :toy_feature }
  validates :name, :presence => true, :cardinality => { :maximum => 1 }
  unique :name

  def initialize(attributes = {})
    super(attributes)
  end
end

class ToyObject < Goo::Base::Resource
  model :toy_object
  validates :parts, :instance_of => { :with => :toypart }
  validates :name, :presence => true, :cardinality => { :maximum => 1 }
  unique :name

  def initialize(attributes = {})
    super(attributes)
  end
end

class TestModelSearch < TestCase

  def initialize(*args)
    super(*args)
    voc = Goo::Naming.get_vocabularies
    if not voc.is_type_registered? :toy_object
      voc.register_model(:foaf, :toy_object , ToyObject)
      voc.register_model(:foaf, :toy_part , ToyPart)
      voc.register_model(:foaf, :toy_feature , ToyFeature)
      voc.register_model(:foaf, :color , Color)
    else
      raise StandarError, "Error conf unit test" if :toy_object != voc.get_model_registry(ToyObject)[:type]
      raise StandarError, "Error conf unit test" if :toy_part != voc.get_model_registry(ToyPart)[:type]
      raise StandarError, "Error conf unit test" if :toy_feature != voc.get_model_registry(ToyFeature)[:type]
      raise StandarError, "Error conf unit test" if :color != voc.get_model_registry(Color)[:type]
    end
  end
 
  def create_toy_parts()
    list = ToyFeature.search({})
    list.each do |f|
      f.load
      f.delete
    end
    list = Color.search({})
    list.each do |c|
      c.load
      c.delete
    end

    blue = Color.new({:code => "blue"})
    red = Color.new({:code => "red"})
    white = Color.new({:code => "white"})

    wheel_blue = ToyFeature.new(:description => "wheel", :color => [white])
    wheel_red = ToyFeature.new(:description => "wheel", :color => [red])
    engine = ToyFeature.new(:description => "engine", :color => [blue, red])
    wheel_blue.save
    wheel_red.save
    engine.save
    list = ToyFeature.search({})
    assert_equal 3, list.length
    list = Color.search({})
    assert_equal 3, list.length
  end 

  def create_toys(max)
    create_toy_parts()
    (0..max-1).each do |n|
      toy = ToyObject.new
      toy.name = "some value for #{n}"
      if n % 2 == 0
        toy.name_even = n
        toy.name_x = "x"

        #two different ways of searching for features
        white = Color.search({:code => "white"})[0]
        white_wheel = ToyFeature.search({:description => "wheel" , :color => white})
        red_wheel = ToyFeature.search({:description => "wheel" , :color => { :code => "red"}})
        toy_part = ToyPart.new({:name => "toypart", :feature => [white_wheel,red_wheel] })
      else
        toy.name_odd = n
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
      lits << t.name
    end
    (0..max-1).each do |n|
      assert_equal true, (lits.include? "some value for #{n}")
    end
    toys = ToyObject.search({:name_x => "x" })
    assert_equal max/2, toys.length
    toys.each do |t|
      t.load
      assert_instance_of Fixnum, t.name_even[0]
      assert_equal 0, t.name_even[0] % 2
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


