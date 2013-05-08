require_relative 'test_case'

GooTest.configure_goo

module TestSChemaless

  NEMO_NS = 

  class Klass < Goo::Base::Resource
    model :class, namespace: :owl, name_with: lambda { |k| k.id }  
    attribute :label, namespace: :rdfs
    attribute :synonym, namespace: :nemo, enforce: [:list]
    attribute :definition, namespace: :nemo, enforce: [:list]
    attribute :comment, namespace: :nemo, enforce: [:list]
    attribute :onto_definition, namespace: :nemo, enforce: [:list]
    attribute :subClassOf, namespace: :rdfs, enforce: [:class, :list]
  end

  class TestSchemaless < MiniTest::Unit::TestCase

    def initialize(*args)
      super(*args)
    end

    def setup
    end

    def self.before_suite
      graph = RDF::URI.new("http:://example.org/data/nemo")
      ntriples_file_path = "./test/data/nemo_ontology.ntriples"

      result = Goo.sparql_data_client.put_triples(
                            graph,
                            ntriples_file_path,
                            mime_type="application/x-turtle")
    end

    def self.after_suite
      graph = RDF::URI.new("http:://example.org/data/nemo")
      result = Goo.sparql_data_client.delete_graph(graph)
    end

    def test_find_include_schemaless
      cognition_term = RDF::URI.new "http://purl.bioontology.org/NEMO/ontology/NEMO.owl#NEMO_5400000"
      k = Klass.find(cognition_term)
      binding.pry


    end
  end
end
