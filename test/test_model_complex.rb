require_relative 'test_case'

TestInit.configure_goo

class Submission < Goo::Base::Resource
  attribute :name , :unique => true
end

class Term < Goo::Base::Resource
  model :class,
        :on_initialize => lambda { |t| t.load_attributes([:prefLabel, :synonyms, :definitions]) },
        :namespace => :owl

  attribute :resource_id #special attribute to name the object manually

  attribute :submission, :collection => lambda { |s| s.resource_id }

  attribute :prefLabel, :single_value => true , :namespace => :skos
  attribute :synonyms, :namespace => :skos, :name => :altLabel
  attribute :definitions, :namespace => :skos, :name => :definition
  attribute :deprecated, :namespace => :owl

  attribute :parents, :namespace => :rdfs, :name => :subClassOf
  attribute :children, :namespace => :rdfs, :name => :subClassOf, :inverse_of => { :with => :term , :attribute => :parents }
end

class TestModelComplex < TestCase


  def initialize(*args)
    super(*args)
  end

  def test_collection()

    submission = Submission.new(name: "submission1")
    unless submission.exist?
      submission.save
    else
      submission = Submission.find("submission1")
    end

    terms = Term.where submission: submission
    terms.each do |t|
      #TODO load collection on load.
      t.load
      t.delete
    end

    vehicle = Term.new
    vehicle.submission = submission
    vehicle.prefLabel = "vehicle"
    vehicle.synonyms = ["transport", "vehicles"]
    vehicle.definitions = ["vehicle def 1", "vehicle def 2"]
    assert !vehicle.valid?
    assert !vehicle.errors[:resource_id].nil?
    vehicle.resource_id = RDF::IRI.new "http://someiri.org/vehicle"
    assert vehicle.valid?
    vehicle.save
    assert_equal 1, count_pattern("GRAPH <#{submission.resource_id.value}> { #{vehicle.resource_id.to_turtle} a ?type . }")

    #where should not accept resource id
    assert_raise ArgumentError do
      Term.where submission: submission, resource_id: "http://someiri.org/vehicle"
    end

    #should fail because there is no :unique
    assert_raise ArgumentError do
      Term.find("xx")
    end

    #find should receive IRI objects
    assert_raise ArgumentError do
      ts = Term.find("http://someiri.org/vehicle", submission: submission)
    end

    #single term retrieval
    ts = Term.find(RDF::IRI.new("http://someiri.org/vehicle"), submission: submission)
    assert_instance_of Term, ts
    assert "vehicle" == ts.prefLabel
    assert ts.synonyms.length == 2
    assert ts.synonyms.include? "transport"
    assert ts.synonyms.include?  "vehicles"

    #all terms for a collection
    terms = Term.where submission: submission
    assert terms.length == 1
    term = terms[0]
    term.load
    term.submission.resource_id.value == "http://goo.org/default/submission/submission1"
    term.deprecated = false
    term.save

    assert_raise ArgumentError do
      terms = Term.all
    end
  end

  def test_parents_inverse_childrent

    vehicle = Term.new
    vehicle.resource_id = RDF::IRI.new "http://someiri.org/vehicle"
    vehicle.submission = submission
    vehicle.prefLabel = "vehicle"
    vehicle.synonyms = ["transport", "vehicles"]
    vehicle.definitions = ["vehicle def 1", "vehicle def 2"]
    assert vehicle.valid?
    vehicle.save

    van = Term.new
    van.submission = submission
    van.prefLabel = "van"
    van.synonyms = ["cargo", "syn van"]
    van.definitions = ["vehicle def 1", "vehicle def 2"]
    van.parents = vehicle

    cargo = Term.new
    cargo.submission = submission
    cargo.prefLabel = "cargo"
    cargo.synonyms = ["cargo yy", "cargo xx"]
    cargo.definitions = ["cargo def 1", "cargo def 2"]
    cargo.parents = vehicle

    minivan = Term.new
    minivan.submission = submission
    minivan.prefLabel = "minivan"
    minivan.synonyms = ["mini-van", "syn minivan"]
    minivan.definitions = ["minivan def 1", "minivan def 2"]
    minivan.parents = van
    assert_raise ArgumentError do
      #children as inverse cannot be assigned
      minivan.children = cargovan
    end

    cargovan = Term.new
    cargovan.submission = submission
    cargovan.prefLabel = "cargovan"
    cargovan.synonyms = ["cargo van", "syn cargovan"]
    cargovan.definitions = ["cargovan def 1", "cargovan def 2"]
    cargovan.parents = [cargo, van]
  end


end

