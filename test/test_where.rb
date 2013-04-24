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

    st = University.where(name: "Stanford")
    assert st.length == 1
    st = st.first
    assert st.instance_of?(University)

    #nothing is loaded
    st.class.attributes.each do |attr|
      assert_raises Goo::Base::AttributeNotLoaded do
        st.send("#{attr}")
      end
    end

    st = University.where(name: "Stanford", include: University.attributes)
    assert st.length == 1
    st = st.first
    assert assert st.instance_of?(University)
    assert st.name == "Stanford"
    assert_raises Goo::Base::AttributeNotLoaded do
      st.programs
    end
    #
    #all includes inverse
    st = University.where(name: "Stanford", include: University.attributes(:all))
    assert st.length == 1
    st = st.first
    assert st.instance_of?(University)
    assert st.name == "Stanford"
    assert st.programs.length == 3
    #programs here are not loaded
    pr = st.programs[0]
    pr.class.attributes.each do |attr|
      assert_raises Goo::Base::AttributeNotLoaded do
        pr.send("#{attr}")
      end
    end
    program_ids = ["http://example.org/program/Stanford/BioInformatics",
 "http://example.org/program/Stanford/CompSci",
 "http://example.org/program/Stanford/Medicine"]
   assert st.programs.map { |x| x.id.to_s }.sort == program_ids

  end

  def test_embed

    #embed name of the programs
    st = University.where(name: "Stanford", include: [programs: [:name]])[0]
    assert st.programs.length == 3
    st.programs.each do |pr|
      pr.name
      assert_raises Goo::Base::AttributeNotLoaded do
        pr.students
      end
    end


  end


  def test_aggregated
    #universities with more than 3 programs
  end

  def test_or
  end

  def test_unbound
    #unbound ... like with no parents
  end

  def test_multiple
    #one student in two programs
  end

end
