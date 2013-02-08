require_relative 'test_case'

TestInit.configure_goo

class Submission < Goo::Base::Resource
  attribute :name , :unique => true
end

class Term < Goo::Base::Resource
  model :term, :on_initialize => lambda { |t| t.load_attributes([:prefLabel, :synonyms, :definitions]) }

  attribute :submission, :collection => lambda { |s| s.resource_id }, :instance_of => { :with => :submission }

  attribute :prefLabel, :namespace => :skos
  attribute :synonyms, :namespace => :skos, :name => :altLabel
  attribute :definitions, :namespace => :skos, :name => :definition

  attribute :parents, :namespace => :rdfs, :name => :subClassOf
  attribute :children, :namespace => :rdfs, :name => :subClassOf, :inverse_of => { :with => :term , :attribute => :parents }
end




class TestModelComplex < TestCase


    def flush
    end

end

