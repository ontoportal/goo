# Start simplecov if this is a coverage task
if ENV["COVERAGE"].eql?("true")
  require 'simplecov'
  SimpleCov.start do
    add_filter "/test/"
    add_filter "app.rb"
    add_filter "init.rb"
    add_filter "/config/"
  end
end

require 'minitest/unit'
MiniTest::Unit.autorun

require_relative "../lib/goo.rb"

class GooUnit < MiniTest::Unit
  def before_suites
    # code to run before the first test (gets inherited in sub-tests)
  end

  def after_suites
    # code to run after the last test (gets inherited in sub-tests)
  end

  def _run_suites(suites, type)
    begin
      before_suites
      super(suites, type)
    ensure
      after_suites
    end
  end

  def _run_suite(suite, type)
    begin
      suite.before_suite if suite.respond_to?(:before_suite)
      super(suite, type)
    ensure
      suite.after_suite if suite.respond_to?(:after_suite)
    end
  end
end

GooUnit.runner = GooUnit.new

module TestInit
  def self.configure_goo
    if not Goo.configure?
      Goo.configure do |conf|

        conf.add_namespace(:omv, RDF::Vocabulary.new("http://omv.org/ontology/"))
        conf.add_namespace(:skos, RDF::Vocabulary.new("http://www.w3.org/2004/02/skos/core#"))
        conf.add_namespace(:owl, RDF::Vocabulary.new("http://www.w3.org/2002/07/owl#"))
        conf.add_namespace(:rdfs, RDF::Vocabulary.new("http://www.w3.org/2000/01/rdf-schema#"))
        conf.add_namespace(:goo, RDF::Vocabulary.new("http://goo.org/default/"),default=true)
        conf.add_namespace(:metadata, RDF::Vocabulary.new("http://goo.org/metadata/"))
        conf.add_namespace(:foaf, RDF::Vocabulary.new("http://xmlns.com/foaf/0.1/"))
        conf.add_namespace(:rdf, RDF::Vocabulary.new("http://www.w3.org/1999/02/22-rdf-syntax-ns#"))

        conf.add_sparql_backend(:main, query: "http://localhost:9000/sparql/",
                                data: "http://localhost:9000/data/",
                                update: "http://localhost:9000/update/",
                                options: { rules: :NONE })
        conf.add_search_backend(:main, service: "http://ncbo-dev-app-02.stanford.edu:8080/solr/" )

      end
    end
  end
end

class TestCase < MiniTest::Unit::TestCase
  def no_triples_for_subject(resource_id)
    rs = Goo.store().query("SELECT * WHERE { #{resource_id.to_turtle} ?p ?o }")
    rs.each_solution do |sol|
      #unreachable
      assert_equal 1,0
    end
  end

  def count_pattern(pattern)
    q = "SELECT * WHERE { #{pattern} }"
    rs = Goo.store().query(q)
    count = 0
    rs.each_solution do |sol|
      count = count + 1
    end
    return count
  end

  def initialize(*args)
    super(*args)
  end
end
