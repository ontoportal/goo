require_relative 'test_case'

#name AAA to make sure this is the first test to run
class TestAAAConfiguration < TestCase

  def setup
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
  end

  def test_vocab_configuration
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
  end

 end
