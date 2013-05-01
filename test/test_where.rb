require_relative 'test_case'

GooTest.configure_goo

PROGRAMS_AND_CATEGORIES = [ ["BioInformatics",["Medicine","Biology","Computer Science"]],
            ["CompSci",["Engineering","Mathematics","Computer Science", "Electronics"]],
            ["Medicine", ["Medicine", "Chemistry", "Biology"]]]

#collection on attribute
class University < Goo::Base::Resource
  model :university
  attribute :name, enforce: [ :existence, :unique]
  attribute :programs, inverse: { on: :program, attribute: :university }
  attribute :address, enforce: [ :existence, :min_1, :list, :address]

  def initialize(attributes = {})
    super(attributes)
  end
end

class Address < Goo::Base::Resource
  model :address, name_with: lambda { |p| id_generator(p) }
  attribute :line1, enforce: [ :existence ]
  attribute :line2
  attribute :country, enforce: [ :existence ]
  def self.id_generator(p)
    return RDF::URI.new("http://example.org/address/#{p.line1}+#{p.line2}+#{p.country}")
  end
end

class Program < Goo::Base::Resource
  model :program, name_with: lambda { |p| id_generator(p) } 
  attribute :name, enforce: [ :existence, :unique ]
  attribute :students, inverse: { on: :student, attribute: :enrolled }
  attribute :university, enforce: [ :existence, :university ]
  attribute :category, enforce: [ :existence, :category, :list ]
  def self.id_generator(p)
    return RDF::URI.new("http://example.org/program/#{p.university.name}/#{p.name}")
  end
end

class Category < Goo::Base::Resource
  model :category
  attribute :code, enforce: [ :existence, :unique ]
end

class Student < Goo::Base::Resource
  model :student
  attribute :name, enforce: [ :existence, :unique ]
  attribute :enrolled, enforce: [:list, :program]
  attribute :birth_date, enforce: [:date_time, :existence]
end


class TestWhere < MiniTest::Unit::TestCase

  def initialize(*args)
    super(*args)
  end

  def setup
  end

  def self.before_suite
    begin
      addresses = {}
      addresses["Stanford"] = [ Address.new(line1: "bla", line2: "foo", country: "EN").save ]
      addresses["Southampton"] = [ Address.new(line1: "bla", line2: "foo", country: "US").save ]
      addresses["UPM"] = [ Address.new(line1: "bla", line2: "foo", country: "SP").save ]
      ["Stanford", "Southampton", "UPM"].each do |uni_name|
        if University.find(uni_name).nil?
          University.new(name: uni_name, address: addresses[uni_name]).save
          PROGRAMS_AND_CATEGORIES.each do |p,cs|
            categories = []
            cs.each do |c|
              categories << (Category.find(c) || Category.new(code: c).save)
            end
            prg = Program.new(name: p, category: categories, 
                              university: University.find(uni_name, include: [:name]))
            binding.pry if !prg.valid?
            prg.save if !prg.exist?
          end
        end
      end
    rescue Exception => e
      binding.pry
    end
  end

  def self.after_suite
    objects = [Student, University, Program, Category, Address]
    objects.each do |obj|
      obj.all(include: obj.attributes).each do |i|
        i.delete
      end
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

  def test_all
    cats = Category.all(include: Category.attributes)
    cats.each do |cats|
      assert_instance_of String, cats.code
    end
    assert University.all.length == 3
    assert Address.all.length == 3
    assert Category.all.length == 7
  end

  def test_embed
    programs = Program.all(include: [ :name, university: [:name], category: [:code]] )
    assert programs.length == 9
    programs.each do |p|
      assert_instance_of String, p.name
      assert_instance_of University, p.university
      assert_instance_of Array, p.category
      assert p.category.length == p.category.select { |x| x.instance_of? Category }.length
      assert_instance_of String, p.university.name
      assert p.id.to_s[p.university.name]
      PROGRAMS_AND_CATEGORIES.each do |x|
        if p.id.to_s[x[0]]
          assert x[1].length == p.category.length
          p.category.each do |c|
            assert_instance_of String, c.code
            assert (x[1].index c.code)
          end
          break
        end
      end
    end
  end

  def test_embed_with_inverse
    unis = University.all(include: [:name, programs: [:name]])
    unis.each do |u|
      assert_instance_of String, u.name
      assert_instance_of Array, u.programs
      u.programs.each do |p|
        assert_instance_of String, p.name
      end
    end
  end

  def test_embed_two_levels
    unis = University.all(include: [:name, programs: [:name, category: [:code]]])
    unis.each do |u|
      assert_instance_of String, u.name
      assert_instance_of Array, u.programs
      u.programs.each do |p|
        assert_instance_of String, p.name
        assert_instance_of Array, p.category
        p.category.each do |c|
          assert_instance_of String, c.code
        end
      end
    end
  end


  def test_where_on_links_and_embed


    #students enrolled in a specific program
    #Student.where(program: Program.find("http://example.org/program/Stanford/Medicine"), 
    #              include: [:name, :birth_date, programs: [:name]])

    #Students in a university
    #Student.where(
    #  program: [university: University.find("Stanford")], 
    #  include: [programs: [:name], :name, :birth_date] )

    #Students in a university by name
    #Student.where(program: [university: [name: "Stanford"]], 
    #              include: [programs: [:name, university: [ :location ]], :name] )


    #universities with a program in a category
    #University.where(program: [category: Category.find("Science") ], include: [:name])

  end

  def test_where_and
    #I need a program in two unis
    #Student.where(
    #  program: [university: University.find("Stanford").and(University.find("Southampton")) ],
    #  include: [programs: [:name, university: [:location, :name]])
  end

  def test_where_or
    #Student.where(
    #  program: [university: University.find("Stanford").or(University.find("Southampton")) ],
    #  include: [programs: [:name, university: [:location, :name]])
  end


  def test_filter
    #f = Filter.greater(DateTime.parse('2001-02-03')).less(DateTime.parse('2021-02-03'))
    #student = Student.where(birth_date: f, include: [:name, programs: [:name], :birth_date])
  end

  def test_aggregated
    #agg = Aggregate.count(:enrolled) #programs_count as default
    #agg = Aggregate.count(:enrolled, attribute: :programs_count)

    #student = Student.all(include: agg)

    #students enrolled in more than 1 program and get the programs name
    #student = Student.where(programs_count: Filter.greater(2).less(10) , 
    #                        include: [agg, :name, :birth_date])

    #universities with more than 3 programs
    #universities with more than 3 students
    #universities where students per program is > 20 
    #
    #universities with more than two addresses in the US
  end

  def test_where_with_lambda
  end

  def test_unbound
    #unbound ... like with no parents
    #not exist SPARQL 1.1
  end

  def test_multiple
    #one student in two programs
  end

end
