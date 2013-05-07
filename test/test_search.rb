require_relative 'test_case'

TestInit.configure_goo

def get_doc(res)
  doc = {
      :resource_id => res.resource_id.value,
      :prefLabel => res.prefLabel,
      :synonym => res.synonym,
      :notation => res.notation,
      :submissionAcronym => res.submissionAcronym,
      :submissionId => res.submissionId,
      :definition => res.definition
  }
  all_attrs = res.attributes.dup
  all_attrs.delete :internals
  all_attrs.delete :uuid
  all_attrs.delete :id
  props = []

  all_attrs.each do |attr_key, attr_val|
    if (!doc.include?(attr_key))
      if (attr_val.is_a?(Array))
        attr_val.uniq!
        attr_val.map { |val| props << val.value.strip }
      else
        props << attr_val.value.strip
      end
    end
  end
  props.uniq!
  doc[:property] = props
  return doc
end

class TermSearch < Goo::Base::Resource
  model :term_search
  attribute :id, :single_value => true
  attribute :prefLabel, :not_nil => true, :single_value => true
  attribute :synonym  #array of strings
  attribute :definition  #array of strings
  attribute :submissionAcronym, :not_nil => true, :single_value => true
  attribute :submissionId, :not_nil => true, :single_value => true

  # dummy attributes to validate non-searchable fileds
  attribute :notation
  attribute :umlsCui
  attribute :prop1
  attribute :prop2
  attribute :prop3

  search_options :index_id => lambda { |t| "#{t.id}_#{t.submissionAcronym}_#{t.submissionId}" },
                 :document => lambda { |t| get_doc(t) }

  def initialize(attributes = {})
    super(attributes)
  end
end

class TestModelSearch < TestCase

  def setup
    @terms = [
      TermSearch.new(
        :id => "http://ncicb.nci.nih.gov/xml/owl/EVS/Thesaurus.owl#Melanoma",
        :prefLabel => "Melanoma",
        :synonym => ["Cutaneous Melanoma", "Skin Cancer", "Malignant Melanoma"],
        :definition => ["Melanoma refers to a malignant skin cancer"],
        :submissionAcronym => "NCIT",
        :submissionId => 2,
        :notation => "Melanoma",
        :umlsCui => "C0025202",
        :prop1 => ["test prop1 [1] for Melanoma", "test prop1 [2] for Melanoma"],
        :prop2 => "another prop 2 for Melanoma"
      ),
      TermSearch.new(
        :id => "http://ncicb.nci.nih.gov/xml/owl/EVS/Thesaurus.owl#Neoplasm",
        :prefLabel => "Neoplasm",
        :synonym => ["tumor", "Neoplasms", "NEOPLASMS BENIGN", "MALIGNANT AND UNSPECIFIED (INCL CYSTS AND POLYPS)", "Neoplasia", "Neoplastic Growth"],
        :definition => ["A benign or malignant tissue growth resulting from uncontrolled cell proliferation. Benign neoplastic cells resemble normal cells without exhibiting significant cytologic atypia, while malignant cells exhibit overt signs such as dysplastic features, atypical mitotic figures, necrosis, nuclear pleomorphism, and anaplasia. Representative examples of benign neoplasms include papillomas, cystadenomas, and lipomas; malignant neoplasms include carcinomas, sarcomas, lymphomas, and leukemias."],
        :submissionAcronym => "NCIT",
        :submissionId => 2,
        :notation => "Neoplasm",
        :umlsCui => "C0375111",
        :prop1 => ["test prop1 [1] for Neoplasm", "test prop1 [2] for Neoplasm"],
        :prop2 => "another prop 2 for Neoplasm",
        :prop3 => "this is prop3 for Neoplasm"
      )
    ]
  end

  def teardown
  end

  def initialize(*args)
    super(*args)
  end

  def test_search
    TermSearch.indexClear()
    @terms[1].index()
    TermSearch.indexCommit()
    resp = TermSearch.search(@terms[1].prefLabel)
    assert_equal(1, resp["response"]["docs"].length)
    assert_equal @terms[1].prefLabel, resp["response"]["docs"][0]["prefLabel"]
  end

  def test_unindex
    TermSearch.indexClear()
    @terms[1].index()
    TermSearch.indexCommit()
    resp = TermSearch.search(@terms[1].prefLabel)
    assert_equal(1, resp["response"]["docs"].length)

    @terms[1].unindex()
    TermSearch.indexCommit()
    resp = TermSearch.search(@terms[1].prefLabel)
    assert_equal(0, resp["response"]["docs"].length)
  end

  def test_unindexByQuery
    TermSearch.indexClear()
    @terms[1].index()
    TermSearch.indexCommit()
    resp = TermSearch.search(@terms[1].prefLabel)
    assert_equal(1, resp["response"]["docs"].length)

    query = "submissionAcronym:" + @terms[1].submissionAcronym
    TermSearch.unindexByQuery(query)
    TermSearch.indexCommit()

    resp = TermSearch.search(@terms[1].prefLabel)
    assert_equal(0, resp["response"]["docs"].length)
  end

  def test_index
    TermSearch.indexClear()
    @terms[0].index()
    TermSearch.indexCommit()
    resp = TermSearch.search(@terms[0].prefLabel)
    assert_equal(1, resp["response"]["docs"].length)
    assert_equal @terms[0].prefLabel, resp["response"]["docs"][0]["prefLabel"]
  end

  def test_indexBatch
    TermSearch.indexClear()
    TermSearch.indexBatch(@terms)
    TermSearch.indexCommit()
    resp = TermSearch.search("*:*")
    assert_equal(2, resp["response"]["docs"].length)
  end

  def test_unindexBatch
    TermSearch.indexClear()
    TermSearch.indexBatch(@terms)
    TermSearch.indexCommit()
    resp = TermSearch.search("*:*")
    assert_equal(2, resp["response"]["docs"].length)

    TermSearch.unindexBatch(@terms)
    TermSearch.indexCommit()
    resp = TermSearch.search("*:*")
    assert_equal(0, resp["response"]["docs"].length)
  end

  def test_indexClear
    TermSearch.indexClear()
    TermSearch.indexCommit()
    resp = TermSearch.search("*:*")
    assert_equal(0, resp["response"]["docs"].length)
  end
end
