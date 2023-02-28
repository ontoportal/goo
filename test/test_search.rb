require_relative 'test_case'

module TestSearch

  class TermSearch < Goo::Base::Resource
    model :term_search, name_with: :id
    attribute :prefLabel, enforce: [:existence]
    attribute :synonym  # array of strings
    attribute :definition  # array of strings
    attribute :submissionAcronym, enforce: [:existence]
    attribute :submissionId, enforce: [:existence, :integer]

    # Dummy attributes to validate non-searchable files
    attribute :semanticType
    attribute :cui

    def index_id()
      "#{self.id.to_s}_#{self.submissionAcronym}_#{self.submissionId}"
    end

    def index_doc(to_set = nil)
      self.to_hash
    end
  end

  class TestModelSearch < MiniTest::Unit::TestCase

    def setup
      @terms = [
        TermSearch.new(
          id: RDF::URI.new("http://ncicb.nci.nih.gov/xml/owl/EVS/Thesaurus.owl#Melanoma"),
          prefLabel: "Melanoma",
          synonym: [
            "Cutaneous Melanoma",
            "Skin Cancer",
            "Malignant Melanoma"
          ],
          definition: "Melanoma refers to a malignant skin cancer",
          submissionAcronym: "NCIT",
          submissionId: 2,
          semanticType: "Neoplastic Process",
          cui: "C0025202"
        ),
        TermSearch.new(
          id: RDF::URI.new("http://ncicb.nci.nih.gov/xml/owl/EVS/Thesaurus.owl#Neoplasm"),
          prefLabel: "Neoplasm",
          synonym: [
            "tumor",
            "Neoplasms",
            "NEOPLASMS BENIGN",
            "MALIGNANT AND UNSPECIFIED (INCL CYSTS AND POLYPS)",
            "Neoplasia",
            "Neoplastic Growth"
          ],
          definition: "A benign or malignant tissue growth resulting from uncontrolled cell proliferation. "\
            "Benign neoplastic cells resemble normal cells without exhibiting significant cytologic atypia, while "\
            "malignant cells exhibit overt signs such as dysplastic features, atypical mitotic figures, necrosis, "\
            "nuclear pleomorphism, and anaplasia. Representative examples of benign neoplasms include papillomas, "\
            "cystadenomas, and lipomas; malignant neoplasms include carcinomas, sarcomas, lymphomas, and leukemias.",
          submissionAcronym: "NCIT",
          submissionId: 2,
          semanticType: "Neoplastic Process",
          cui: "C0375111"
        )
      ]
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
      assert_equal 1, resp["response"]["docs"].length

      query = "submissionAcronym:" + @terms[1].submissionAcronym
      TermSearch.unindexByQuery(query)
      TermSearch.indexCommit()

      resp = TermSearch.search(@terms[1].prefLabel)
      assert_equal 0, resp["response"]["docs"].length
    end

    def test_index
      TermSearch.indexClear()
      @terms[0].index()
      TermSearch.indexCommit()
      resp = TermSearch.search(@terms[0].prefLabel)
      assert_equal 1, resp["response"]["docs"].length
      assert_equal @terms[0].prefLabel, resp["response"]["docs"][0]["prefLabel"]
    end

    def test_indexBatch
      TermSearch.indexClear()
      TermSearch.indexBatch(@terms)
      TermSearch.indexCommit()
      resp = TermSearch.search("*:*")
      assert_equal 2, resp["response"]["docs"].length
    end

    def test_unindexBatch
      TermSearch.indexClear()
      TermSearch.indexBatch(@terms)
      TermSearch.indexCommit()
      resp = TermSearch.search("*:*")
      assert_equal 2, resp["response"]["docs"].length

      TermSearch.unindexBatch(@terms)
      TermSearch.indexCommit()
      resp = TermSearch.search("*:*")
      assert_equal 0, resp["response"]["docs"].length
    end

    def test_indexClear
      TermSearch.indexClear()
      TermSearch.indexCommit()
      resp = TermSearch.search("*:*")
      assert_equal 0, resp["response"]["docs"].length
    end
  end

end
