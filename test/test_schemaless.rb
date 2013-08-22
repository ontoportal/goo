require_relative 'test_case'

GooTest.configure_goo

module TestSChemaless

  ONT_ID = "http:://example.org/data/nemo"

  class Ontology < Goo::Base::Resource
    model :ontology, name_with: lambda { |k| k.id }
    attribute :name
  end 

  class Klass < Goo::Base::Resource
    model :class, namespace: :owl, name_with: :id,
           collection: :ontology
    attribute :ontology, enforce: [:ontology]

    attribute :label, namespace: :rdfs
    attribute :synonym, namespace: :nemo, enforce: [:list]
    attribute :definition, namespace: :nemo, enforce: [:list]
    attribute :comment, namespace: :nemo, enforce: [:list]
    attribute :onto_definition, namespace: :nemo, enforce: [:list]
    attribute :parents, namespace: :rdfs, property: :subClassOf,
                        enforce: [:class, :list]
  end

  class TestSchemaless < MiniTest::Unit::TestCase

    def initialize(*args)
      super(*args)
    end


    def self.before_suite
      graph = RDF::URI.new(ONT_ID)

      ont = Ontology.new
      ont.id = RDF::URI.new ONT_ID
      ont.name = "some ont"
      ont.save unless ont.exist?

      ntriples_file_path = "./test/data/nemo_ontology.ntriples"

      result = Goo.sparql_data_client.put_triples(
                            graph,
                            ntriples_file_path,
                            mime_type="application/x-turtle")
    end

    def self.after_suite
      graph = RDF::URI.new(ONT_ID)
      result = Goo.sparql_data_client.delete_graph(graph)
      ont = Ontology.find(ONT_ID).first
      ont.delete if ont
    end

    def test_find_include_schemaless
      ontology = Ontology.find(RDF::URI.new(ONT_ID)).first
      cognition_term = RDF::URI.new( 
          "http://purl.bioontology.org/NEMO/ontology/NEMO.owl#NEMO_5400000")
      k = Klass.find(cognition_term).in(ontology).first
      assert k.id.to_s == cognition_term 
      assert_raises Goo::Base::AttributeNotLoaded do
        k.label
      end
      k = Klass.find(cognition_term).in(ontology).include(:label).first
      assert k.ontology.id == ONT_ID
      assert k.id.to_s == cognition_term 
      assert k.label == "working_memory"
      assert_raises Goo::Base::AttributeNotLoaded do
        k.definition
      end
      k = Klass.find(cognition_term).in(ontology).include(Klass.attributes).first
      assert k.label == "working_memory"
      assert k.definition.length == 1
      assert k.definition.first["a cognitive_process is a mental process"]
      assert k.synonym.sort == ["cognition",
 "http://ontology.neuinfo.org/NIF/Function/NIF-Function.owl#birnlex_1800"]
      assert k.comment == []
      assert k.parents.length == 1
      assert k.parents.first.id.to_s == 
        "http://purl.bioontology.org/NEMO/ontology/NEMO.owl#NEMO_4320000"

      k = Klass.find(cognition_term).in(ontology).include(:unmapped).first
      enter = 0
      k.unmapped.each do |p,vals|
        if p.to_s == Goo.vocabulary(:nemo)[:synonym].to_s
          enter += 1
          vals.map { |sy| sy.object }.sort == 
            ["cognition",
             "http://ontology.neuinfo.org/NIF/Function/NIF-Function.owl#birnlex_1800"]
        end
        if p.to_s == Goo.vocabulary(:nemo)[:onto_definition].to_s
          enter += 1
          vals.first.object == 
            "mental_process is a brain_physiological_process that...[incomplete]"
        end
        if p.to_s == Goo.vocabulary(:rdfs)[:label].to_s
          vals.first.object == "working_memory"
          enter += 1
        end
      end
      assert enter == 3
      assert_raises Goo::Base::AttributeNotLoaded do
        k.label
      end
      Klass.map_attributes(k)
      assert k.label == "working_memory"
      assert k.definition.length == 1
      assert k.definition.first["a cognitive_process is a mental process"]
      assert k.synonym.sort == ["cognition",
 "http://ontology.neuinfo.org/NIF/Function/NIF-Function.owl#birnlex_1800"]
      assert k.comment == []
      assert k.parents.length == 1
      assert_instance_of Klass, k.parents.first
      assert k.parents.first.id.to_s == 
        "http://purl.bioontology.org/NEMO/ontology/NEMO.owl#NEMO_4320000"

    end


    def test_find_parent_labels
      ontology = Ontology.find(RDF::URI.new(ONT_ID)).first
      cognition_term = 
        RDF::URI.new "http://purl.bioontology.org/NEMO/ontology/NEMO.owl#NEMO_5400000"
      k = Klass.find(cognition_term).in(ontology).include(parents: [:label]).first
      assert k.parents.first.label == "cognitive_process"
    end


    def test_index_order_by
      #TODO: index not supported
      return

      ontology = Ontology.find(RDF::URI.new(ONT_ID)).first

      Klass.in(ontology).order_by(label: :asc).index_as("my_ontology_by_labels")

      first_page = Klass
                      .in(ontology)
                      .with_index("my_ontology_by_labels")
                      .include(:label, :synonym)
                      .page(1, 100).all

      prev_label = nil
      first_page.each do |k|
        (assert prev_label <= k.label) if prev_label
        prev_label = k.label
      end

    end

    def test_page_reuse_predicates
      ontology = Ontology.find(RDF::URI.new(ONT_ID)).first
      paging = Klass.in(ontology).include(:unmapped).page(1,100)
      predicates_array = nil
      total = 0
      all_ids = []
      begin
        if paging.instance_variable_get("@page_i") > 1
          #we test that the predicates array is always the same object.
          assert predicates_array.object_id == 
            paging.instance_variable_get("@predicates").object_id
        end

        page = paging.to_a

        if paging.instance_variable_get("@page_i") == 1
          predicates_array = paging.instance_variable_get("@predicates")
        end
        page.each do |k|
          all_ids << k.id
        end
        total += page.length
        paging.page(page.next_page) if page.next?
        assert page.aggregate == 1713
      end while(page.next?)
      assert all_ids.length == all_ids.uniq.length
      assert total == 1713
    end

    def test_index_roots
      #TODO: index not supported
      return
      ontology = Ontology.find(RDF::URI.new(ONT_ID)).first
      f = Goo::Filter.new(:parents).unbound
      Klass.in(ontology)
                .filter(f)
                .index_as("my_ontology_roots")

      roots = Klass.in(ontology)
                .with_index("my_ontology_roots")
                .include(:label)
                .all
      roots.each do |r|
        #roots have no parents
        assert Klass.find(r.id).in(ontology).include(:parents).first.parents == []
      end
    end
  end
end
