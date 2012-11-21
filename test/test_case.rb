require 'test/unit'

require_relative "../lib/goo.rb"


class TestCase < Test::Unit::TestCase
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
    if Goo.store().nil?
      Goo.configure do |conf|
        conf[:stores] = [ { :name => :main , :host => "localhost", :port => 8080 , :options => { } } ]
      end
      epr = Goo.store()
      #just testing that sparql_http is integrated
      assert_instance_of SparqlRd::Store::HttpStore::Client, epr
      begin
        #no vabularies object has been declared so error
        Goo::Naming.get_vocabularies
        #unreachable
        assert_equal 1, 0
      rescue => e
        assert_instance_of Goo::Naming::StatusException, e 
      end
      vocab_configuration
    end
  end

  def vocab_configuration
    vocabs = Goo::Naming::Vocabularies.new()
    vocabs.default= "http://goo.org/default/"
    vocabs.register(:omv,"http://omv.org/ontology/", [:name, :nick_name])
    vocabs.register(:dc,"http://purl.org/dc/elements/1.1/", [:birth_date])
    vocabs.register(:foaf,"http://xmlns.com/foaf/0.1/")
    vocabs.add_properties_to_prefix(:foaf, [:points])
    Goo::Naming.register_vocabularies(vocabs)
    begin
      #only one vocabularies can be registerred so error
      Goo::Naming.register_vocabularies 
      #unreachable
      assert_equal 1,0
    rescue => e
      assert_instance_of ArgumentError, e
    end
    vocabs2 = Goo::Naming.get_vocabularies
    assert_equal vocabs, vocabs2
    assert_instance_of String, Goo.uuid.generate
  end

end
