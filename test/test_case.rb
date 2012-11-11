require 'test/unit'

require_relative "../lib/goo.rb"


class TestCase < Test::Unit::TestCase
  def store
    { :name => :main , :host => "localhost", :port => 8080 , :options => { } }
  end
  def test_graph
    "https://github.com/ncbo/sparqlrd/"
  end

  def no_triples_for_subject(resource_id)
    rs = Goo.store().query("SELECT * WHERE { #{resource_id.to_turtle} ?p ?o }")
    rs.each_solution do |sol|
      #unreachable
      assert_equal 1,0
    end
  end

end
