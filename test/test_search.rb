require_relative 'test_case'

TestInit.configure_goo


def get_doc(res)
  attrs = {
      :submissionAcronym => res.submissionAcronym,
      :submissionId => res.submissionId
  }

  object_id = res.resource_id.value
  doc = res.attributes.dup
  doc.delete :internals
  doc.delete :uuid

  doc = doc.merge(attrs)

  doc[:resource_id] = object_id

  return doc
end

class Term < Goo::Base::Resource
  model :term
  attribute :id, :single_value => true
  attribute :prefLabel, :not_nil => true, :single_value => true
  attribute :synonym  #array of strings
  attribute :definition  #array of strings
  attribute :submissionAcronym, :not_nil => true, :single_value => true
  attribute :submissionId, :not_nil => true, :single_value => true

  # dummy attributes to validate non-searchable fileds
  attribute :semanticType
  attribute :umlsCui

  search_options :index_id => lambda { |t| "#{t.id}_#{t.submissionAcronym}_#{t.submissionId}" },
                 :document => lambda { |t| get_doc(t) }

  def initialize(attributes = {})
    super(attributes)
  end
end

class TestModelSearch < TestCase


  def setup
    @terms = [
      Term.new(
        :id => "http://ncicb.nci.nih.gov/xml/owl/EVS/Thesaurus.owl#Melanoma",
        :prefLabel => "Melanoma",
        :synonym => ["Cutaneous Melanoma", "Skin Cancer", "Malignant Melanoma"],
        :definition => "Melanoma refers to a malignant skin cancer",
        :submissionAcronym => "NCIT",
        :submissionId => 2,
        :semanticType => "Neoplastic Process",
        :umlsCui => "C0025202"
      ),
      Term.new(
          :id => "http://ncicb.nci.nih.gov/xml/owl/EVS/Thesaurus.owl#Neoplasm",
          :prefLabel => "Neoplasm",
          :synonym => ["tumor", "Neoplasms", "NEOPLASMS BENIGN", "MALIGNANT AND UNSPECIFIED (INCL CYSTS AND POLYPS)", "Neoplasia", "Neoplastic Growth"],
          :definition => "A benign or malignant tissue growth resulting from uncontrolled cell proliferation. Benign neoplastic cells resemble normal cells without exhibiting significant cytologic atypia, while malignant cells exhibit overt signs such as dysplastic features, atypical mitotic figures, necrosis, nuclear pleomorphism, and anaplasia. Representative examples of benign neoplasms include papillomas, cystadenomas, and lipomas; malignant neoplasms include carcinomas, sarcomas, lymphomas, and leukemias.",
          :submissionAcronym => "NCIT",
          :submissionId => 2,
          :semanticType => "Neoplastic Process",
          :umlsCui => "C0375111"
      )
    ]
  end

  def teardown
  end


  def initialize(*args)
    super(*args)
  end

  def test_search
   # binding.pry

    #@term.unindex
    #@term.index

    Term.search("*:*")

    #terms = Term.where :ontology => Ontology.find("SNOMED")
    #terms.each do |t|
    #  t.index
    #end
    #Terms.indexBatch terms

  end


  def test_unindex
    @terms[0].unindex
  end

  def test_unindexByQuery
    query = "submissionAcronym:" + @terms[0].submissionAcronym
    Term.unindexByQuery query
  end

  def test_index
    @terms[0].index
  end

  def test_indexBatch
    Term.indexBatch(@terms)
  end

  def test_unindexBatch
    Term.unindexBatch(@terms)
  end
end
