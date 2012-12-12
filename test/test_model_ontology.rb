require_relative 'test_case'

TestInit.configure_goo

class Ontology < Goo::Base::Resource
  attribute :acronym, :unique => true, :cardinality => { :max => 1, :min => 1 }
  attribute :name, :cardinality => { :max => 1, :min => 1 }
end

class Project < Goo::Base::Resource
  attribute :name, :cardinality => { :max => 1, :min => 1 }
  attribute :ontologyUsed, :instance_of => { :with => :ontology }, :cardinality => { :min => 1 }
end



class TestModelOntology < TestCase

   def initialize(*args)
      super(*args)
   end

   def test_valid_save
     Project.all.each do |p|
       p.load
       p.delete
     end
     Ontology.all.each do |o|
       o.load
       o.delete
     end
     p = Project.new({
          :name => "Great Project",
          :ontologyUsed => [Ontology.new(acronym: "SNOMED", name: "SNOMED CT")]
        })
      assert_equal false, p.exist?(reload=true)
      p.save
      assert_equal true, p.exist?(reload=true)
      p.delete
      assert_equal false, p.exist?(reload=true)
     Project.all.each do |p|
       p.load
       p.delete
     end
     Ontology.all.each do |o|
       o.load
       o.delete
     end
     assert_equal 0, Project.all.length
     assert_equal 0, Ontology.all.length
   end
end
