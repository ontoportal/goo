require_relative 'test_case'

TestInit.configure_goo

#collection on attribute
class University < Goo::Base::Resource
  model :university
  attribute :name, enforce: [ :existence, :unique]
  attribute :programs, inverse: { on: :progam, attribute: :university }

  def initialize(attributes = {})
    super(attributes)
  end
end

class Program < Goo::Base::Resource
  model :program, name_with: lambda { |p| id_generator(p) } 
  attribute :name, enforce: [ :existence, :unique ]
  attribute :students, inverse: { on: :student, attribute: :enrolled }
  attribute :university, enforce: [ :existence, :university ]
  def id_generator(p)
    return RDF::URI.new("http://example.org/program/#{p.university.name}/#{p.name}")
  end

end

class Student < Goo::Base::Resource
  model :student
  attribute :name, enforce: [ :existence, :unique ]
  attribute :enrolled, enforce: [:list, :program]
end


class TestWhere < TestCase

  def initialize(*args)
    super(*args)
  end

  def before_suite
    ["Stanford", "Southampton", "UPM"].each do |uni_name|
      if University.find(uni_name).nil?
        University.new(name: uni_name).save
        ["BioInformatics", "CompSci", "Medicine"].each do |p|
          prg = Program.new(name: p, university: University.find(uni_name, include: [:name]))
          prg.save if prg.exist?
        end
      end
    end
  end

  def after_suite
    ["Stanford", "Southampton", "UPM"].each do |uni_name|
      u = University.find(uni_name)
      u.programs.each do |p|
        p.delete
      end
      u.delete
    end
  end

  def test_where_simple
    binding.pry
  end

  def test_unbound
    #unbound ... like with no parents
  end

  def test_multiple
    #one student in two programs
  end

end
