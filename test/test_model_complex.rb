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

  attribute :prefLabel, :not_nil => true, :single_value => true , :namespace => :skos
  attribute :synonyms, :namespace => :skos, :name => :altLabel
  attribute :definitions, :namespace => :skos, :name => :definition
  attribute :deprecated, :namespace => :owl

  attribute :parents, :namespace => :rdfs, :name => :subClassOf
  attribute :children, :namespace => :rdfs, :name => :subClassOf, :inverse_of => { :with => :class , :attribute => :parents }

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

  def test_two_resources_same_id
    s1 = Submission.new(name: "sub1")
    if s1.exist?
      s1 = Submission.find("sub1")
    else
      s1.save
    end
    s2 = Submission.new(name: "sub2")
    if s2.exist?
      s2 = Submission.find("sub2")
    else
      s2.save
    end

    [s1, s2].each do |s|
      terms = Term.where submission: s
      terms.each do |t|
        t.load
        t.delete
      end
    end

    t0 = Term.new( prefLabel: "labelX" )
    t0.resource_id = RDF::IRI.new("http://someiri.org/term0")
    t1 = Term.new( prefLabel: "label1" )
    t1.resource_id = RDF::IRI.new("http://someiri.org/term")
    t0.submission = s1
    t1.submission = s1
    t2 = Term.new( prefLabel: "label2" )
    t2.resource_id = RDF::IRI.new("http://someiri.org/term")
    t2.submission = s2

    assert t0.valid?
    assert t1.valid?
    assert t2.valid?

    t0.save
    t1.save
    t2.save

   t1x = Term.find(RDF::IRI.new("http://someiri.org/term"), submission: s1)
   assert t1x.loaded?
   assert t1x.prefLabel ==  "label1"
   t2x = Term.find(RDF::IRI.new("http://someiri.org/term"), submission: s2)
   assert t2x.prefLabel ==  "label2"

   termsS2 = Term.where submission: s2
   assert termsS2.length == 1
   termsS1 = Term.where submission: s1
   assert termsS1.length == 2
   [s1, s2].each do |s|
     terms = Term.where submission: s
     terms.each do |t|
       t.load
       t.delete
     end
   end

  end

  def test_parents_inverse_children

    submission = Submission.new(name: "submission1")
    unless submission.exist?
      submission.save
    else
      submission = Submission.find("submission1")
    end

    terms = Term.where submission: submission
    terms.each do |t|
      t.load
      t.delete
    end

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
    van.resource_id = RDF::IRI.new "http://someiri.org/van"
    van.prefLabel = "van"
    van.synonyms = ["cargo", "syn van"]
    van.definitions = ["vehicle def 1", "vehicle def 2"]
    van.parents = vehicle
    assert van.valid?
    van.save

    cargo = Term.new
    cargo.submission = submission
    cargo.resource_id = RDF::IRI.new "http://someiri.org/cargo"
    cargo.prefLabel = "cargo"
    cargo.synonyms = ["cargo yy", "cargo xx"]
    cargo.definitions = ["cargo def 1", "cargo def 2"]
    cargo.parents = vehicle
    assert cargo.valid?
    cargo.save

    minivan = Term.new
    minivan.submission = submission
    minivan.resource_id = RDF::IRI.new "http://someiri.org/minivan"
    minivan.prefLabel = "minivan"
    minivan.synonyms = ["mini-van", "syn minivan"]
    minivan.definitions = ["minivan def 1", "minivan def 2"]
    minivan.parents = van
    assert minivan.valid?
    minivan.save


    cargovan = Term.new
    cargovan.submission = submission
    cargovan.resource_id = RDF::IRI.new "http://someiri.org/cargovan"
    cargovan.prefLabel = "cargovan"
    cargovan.synonyms = ["cargo van", "syn cargovan"]
    cargovan.definitions = ["cargovan def 1", "cargovan def 2"]
    cargovan.parents = [cargo, van]
    assert cargovan.valid?
    cargovan.save

    assert_raise ArgumentError do
      #children as inverse cannot be assigned
      minivan.children = cargovan
    end


    ch = vehicle.children
    assert ch.length == 2
    (ch.select { |c| c.resource_id.value == "http://someiri.org/van" }).length == 1
    (ch.select { |c| c.resource_id.value == "http://someiri.org/cargo" }).length == 1
    assert vehicle.parents.nil?


    assert cargovan.parents.length == 2
    #this is confussing
    assert cargovan.children == []
  end


end

