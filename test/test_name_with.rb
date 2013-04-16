require_relative 'test_case'

TestInit.configure_goo


class NameWith < Goo::Base::Resource
  model :name_with, name_with: lambda { |s| id_generator(s) } 
  attribute :name, enforce: [ :existence, :string ]

  def self.id_generator(inst)
    return RDF::URI.new("http://example.org/" + inst.name + "/bla")
  end
end

class TestNameWith < TestCase
  def initialize(*args)
    super(*args)
  end

  def test_name_with
    nw = NameWith.new(name: "John")
    assert_instance_of(RDF::URI, nw.id)
    assert_equal("http://example.org/John/bla",nw.id.to_s)
    assert !nw.exist?
    nw.save

    from_backend = NameWith.find(RDF::URI.new("http://example.org/John/bla"), include: [:name])
    assert_equal("John", from_backend.name)

    another = NameWith.new(name: "John")
    assert_instance_of(RDF::URI, another.id)
    assert another.exist?
    assert_raises Goo::Base::NotValidException do
      another.save
    end

    from_backend.delete
    assert(!from_backend.exist?)
  end
end
