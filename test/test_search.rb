require_relative 'test_case'

TestInit.configure_goo

class Term < Goo::Base::Resource
  model :term
  attribute :id, :unique => true
  attribute :prefLabel, :not_nil => true, :single_value => true
  attribute :synonym  #array of strings
  attribute :definition  #array of strings
  attribute :submission, :not_nil => true, :single_value => true

  # dummy attributes to validate non-searchable fileds
  attribute :semanticType
  attribute :umlsCui

  def initialize(attributes = {})
    super(attributes)
  end
end

class TestModelSearch < TestCase

  def initialize(*args)
    super(*args)
  end

  def test_search
    t = Term.new(
        :id => "Melanoma",
        :prefLabel => "NCI Thesaurus",
        :synonym => ["Cutaneous Melanoma", "Skin Cancer", "Malignant Melanoma"],
        :definition => "Melanoma refers to a malignant skin cancer",
        :submission => "NCIT",
        :semanticType => "Neoplastic Process",
        :umlsCui => "C0025202"
    )
   # binding.pry

    t.unindex
    t.index

    Term.search("nci")

    #terms = Term.where :ontology => Ontology.find("SNOMED")
    #terms.each do |t|
    #  t.index
    #end
    #Terms.indexBatch terms

  end
end
