require_relative 'test_case'

GooTest.configure_goo

#collection on attribute
class University < Goo::Base::Resource
  model :university
  attribute :name, enforce: [ :existence, :unique]
  attribute :programs, inverse: { on: :program, attribute: :university }

  def initialize(attributes = {})
    super(attributes)
  end
end

class Program < Goo::Base::Resource
  model :program, name_with: lambda { |p| id_generator(p) } 
  attribute :name, enforce: [ :existence, :unique ]
  attribute :students, inverse: { on: :student, attribute: :enrolled }
  attribute :university, enforce: [ :existence, :university ]
  def self.id_generator(p)
    return RDF::URI.new("http://example.org/program/#{p.university.name}/#{p.name}")
  end

end

class Student < Goo::Base::Resource
  model :student
  attribute :name, enforce: [ :existence, :unique ]
  attribute :enrolled, enforce: [:list, :program]
end


class TestWhere < GooTest::TestCase

  def initialize(*args)
    super(*args)
  end

  def self.before_suite
    begin
      ["Stanford", "Southampton", "UPM"].each do |uni_name|
        if University.find(uni_name).nil?
          University.new(name: uni_name).save
          ["BioInformatics", "CompSci", "Medicine"].each do |p|
            prg = Program.new(name: p, university: University.find(uni_name, include: [:name]))
            prg.save if !prg.exist?
          end
        end
      end
    rescue Exception => e
      binding.pry
    end
  end

  def self.after_suite
    ["Stanford", "Southampton", "UPM"].each do |uni_name|
      u = University.find(uni_name, include: [:programs])
      unless u.programs.nil?
        u.programs.each do |p|
          p.delete
        end
      end
      u.delete
    end
  end

  def test_where_simple
    assert University.range(:programs) == Program
    binding.pry
  end

  def test_unbound
    #unbound ... like with no parents
  end

  def test_multiple
    #one student in two programs
  end

end
