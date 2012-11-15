require_relative 'test_case'

class Unnamed < Goo::Base::Resource
  model :unnamed
  validates :name, :presence => true, :cardinality => { :maximum => 1 }

  def initialize(attributes = {})
    super(attributes)
  end
end

class TestModelUnnamed < TestCase

  def initialize(*args)
    super(*args)
    voc = Goo::Naming.get_vocabularies
    if not voc.is_type_registered? :with_no_name
      voc.register_model(:foaf, :with_no_name, Unnamed)
    else
      raise StandarError, "Error conf unit test" if :with_no_name != voc.get_model_registry(Unnamed)[:type]
    end
  end

  def test_unnamed_save
    obj = Unnamed.new
    obj.name = "some value"
    obj.prop1 = 1
    obj.save
    assert_equal true, obj.exists?
    load_obj = Unnamed.new
    load_obj.load(obj.resource_id)
    assert_equal obj.prop1, load_obj.prop1
    assert_equal obj.name, load_obj.name
    load_obj.name= "changed value"
    load_obj.save
    load_obj = Unnamed.new
    load_obj.load(obj.resource_id)
    assert_equal obj.prop1, load_obj.prop1
    assert_equal "changed value", load_obj.name
    assert_equal obj.resource_id.value, load_obj.resource_id.value
    load_obj.delete
    assert_equal false, load_obj.exists?(reload=true)
  end
end
