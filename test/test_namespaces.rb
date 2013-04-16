require_relative 'test_case'

TestInit.configure_goo


class NamespacesModel < Goo::Base::Resource
  model :namespaces, namespace: :rdfs
  attribute :name, enforce: [ :existence, :string, :unique ], namespace: :skos
  attribute :description, enforce: [ :existence, :string ], namespace: :foaf
  attribute :location, enforce: [ :existence, :string ]

  def self.id_generator(inst)
    return RDF::URI.new("http://example.org/" + inst.name + "/bla")
  end
end

class TestNamespaces < TestCase
  def initialize(*args)
    super(*args)
  end

  def test_namespaces
    ns = NamespacesModel.new(name: "John", description: "description", location: "CA")
    assert ns.class.uri_type.to_s["http://www.w3.org/2000/01/rdf-schema#"] != nil
    assert ns.class.attribute_uri(:name).to_s["http://www.w3.org/2004/02/skos/core#"] != nil
    assert ns.class.attribute_uri(:description).to_s["http://xmlns.com/foaf/0.1/"] != nil
    assert ns.class.attribute_uri(:location).to_s["http://goo.org/default/"] != nil
    assert ns.valid?
    ns.save

    assert_equal(1, count_pattern(" #{ns.id.to_ntriples} a #{ns.class.uri_type.to_ntriples} ."))
    assert_equal(1, count_pattern(" #{ns.id.to_ntriples} #{ns.class.attribute_uri(:name).to_ntriples} ?x ."))
    assert_equal(1, count_pattern(" #{ns.id.to_ntriples} #{ns.class.attribute_uri(:description).to_ntriples} ?x ."))
    assert_equal(1, count_pattern(" #{ns.id.to_ntriples} #{ns.class.attribute_uri(:location).to_ntriples} ?x ."))

    from_backend = NamespacesModel.find(ns.id, include: NamespacesModel.attributes)
    NamespacesModel.attributes.each do |attr|
      assert_equal ns.send("#{attr}"), from_backend.send("#{attr}")
    end
    from_backend.delete
    assert !from_backend.exist?
    assert 0, triples_for_subject(from_backend.id)
  end
end
