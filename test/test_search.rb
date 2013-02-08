require_relative 'test_case'

TestInit.configure_goo

class Term < Goo::Base::Resource
  model :term
  attribute :id, :unique => true
  attribute :label

  def initialize(attributes = {})
    super(attributes)
  end
end

class TestModelwhere < TestCase

  def initialize(*args)
    super(*args)
  end

  def test_search
    t = Term.new(:id => "1", :label => "some label")
    binding.pry
    t.index

    Term.search("some")

    #terms = Term.where :ontology => Ontology.find("SNOMED")
    terms.each do |t|
      t.index
    end
    Terms.indexBatch terms
  end
end
