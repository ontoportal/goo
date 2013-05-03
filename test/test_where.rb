require_relative 'test_case'

GooTest.configure_goo

PROGRAMS_AND_CATEGORIES = [ ["BioInformatics",["Medicine","Biology","Computer Science"]],
            ["CompSci",["Engineering","Mathematics","Computer Science", "Electronics"]],
            ["Medicine", ["Medicine", "Chemistry", "Biology"]]]

STUDENTS = [
  ["Susan", DateTime.parse('1978-01-01'), [["BioInformatics", "Stanford"]] ],
  ["John", DateTime.parse('1978-01-02'), [["CompSci", "Stanford"]] ],
  ["Tim", DateTime.parse('1978-01-03'), [["CompSci", "UPM"]] ],
  ["Daniel", DateTime.parse('1978-01-04'), [["CompSci", "Southampton"], ["BioInformatics", "Stanford"]] ],
  ["Louis", DateTime.parse('1978-01-05'), [["Medicine", "Southampton"]]],
  ["Lee", DateTime.parse('1978-01-06'), [["BioInformatics", "Southampton"]]],
  ["Robert", DateTime.parse('1978-01-07'), [["CompSci", "UPM"]]]
]

#collection on attribute
class University < Goo::Base::Resource
  model :university, name_with: :name
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
  attribute :name, enforce: [ :existence ]
  attribute :students, inverse: { on: :student, attribute: :enrolled }
  attribute :university, enforce: [ :existence, :university ]
  attribute :category, enforce: [ :existence, :category, :list ]
  def self.id_generator(p)
    return RDF::URI.new("http://example.org/program/#{p.university.name}/#{p.name}")
  end
end

class Category < Goo::Base::Resource
  model :category, name_with: :code
  attribute :code, enforce: [ :existence, :unique ]
end

class Student < Goo::Base::Resource
  model :student, name_with: :name
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
      addresses["Stanford"] = [ Address.new(line1: "bla", line2: "foo", country: "US").save ]
      addresses["Southampton"] = [ Address.new(line1: "bla", line2: "foo", country: "UK").save ]
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
      STUDENTS.each do |st_data|
        st = Student.new(name: st_data[0], birth_date: st_data[1])
        programs = []
        st_data[2].each do |pr|
          pr = Program.where(name: pr[0], university: [name: pr[1] ])
          pr = pr.first
          programs << pr
        end
        st.enrolled= programs
        st.save
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

  def test_where_1levels
    programs = Program.where(name: "BioInformatics", university: [ name: "Stanford"  ])
    assert programs.length == 1
    assert programs.first.id.to_s["Stanford/BioInformatics"]
  end

  def test_where_2levels
    programs = Program.where(name: "BioInformatics", university: [ address: [ country: "US" ]])
    assert programs.length == 1
    assert programs.first.id.to_s["Stanford/BioInformatics"]
    programs = Program.where(name: "BioInformatics", university: [ address: [ country: "UK" ]])
    assert programs.length == 1
    assert programs.first.id.to_s["Southampton/BioInformatics"]
   
    #any program from universities in the US
    programs = Program.where(university: [ address: [ country: "US" ]], include: [:name])
    assert programs.length == 3
    assert programs.map { |p| p.name }.sort == ["BioInformatics", "CompSci", "Medicine"]
  end

  def test_where_2levels_inverse
    unis = University.where(address: [country: "US"], programs: [category: [code: "Biology"]])
    assert unis.length == 1
    assert unis.first.id.to_s == "http://goo.org/default/university/Stanford"
    unis = University.where(programs: [category: [code: "Biology"]], include: [:name])
    assert unis.length == 3
    assert unis.map { |u| u.name }.sort == ["Southampton", "Stanford", "UPM"]
  end

  def test_embed_include
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

  def test_embed_include_with_inverse
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


  def test_unique_object_references

    #students enrolled in a specific program
    students = Student.where(enrolled: 
                             Program.find(RDF::URI.new("http://example.org/program/Stanford/BioInformatics")), 
                  include: [:name, :birth_date, enrolled: [:name]])
    assert students.length == 2
    assert students.map { |x| x.name }.sort == ["Daniel","Susan"]
    
    #if programs have the same id then the share the same memory reference
    programs = []
    students.each do |st|
      programs.concat(st.enrolled)
    end
    assert programs.length == 3
    programs.each do |p|
      assert_instance_of String, p.name
      programs.each do |p2|
        if p.id == p2.id
          assert p.object_id == p2.object_id
        end
      end
    end
    assert programs.uniq.length == 2

    #Students in a university
    students = Student.where(
      enrolled: [ university: University.find("Stanford") ], 
      include: [:name, :birth_date, enrolled: [category: [:code ]]])
    assert students.length == 3
    assert students.map { |x| x.name }.sort == ["Daniel","John","Susan"]
    students = students.sort_by { |x| x.name  }
    daniel = students.first
    assert daniel.enrolled.map { |p| p.category.map { |c| c.code }.sort }.sort == [
      ["Biology", "Computer Science", "Medicine"],
      ["Computer Science", "Electronics", "Engineering", "Mathematics"]]
    john = students[1]
    assert john.enrolled.map { |p| p.category.map { |c| c.code }.sort }.sort == [
      ["Computer Science", "Electronics", "Engineering", "Mathematics"]]
    susan = students.last
    assert susan.enrolled.map { |p| p.category.map { |c| c.code }.sort }.sort == [
      ["Biology", "Computer Science", "Medicine"]]

    categories = []
    students.each do |st|
      categories.concat(st.enrolled.map { |p| p.category }.flatten)
    end
    assert categories.length == 14
    uniq_object_refs = categories.map { |x| x.object_id }.uniq
    assert uniq_object_refs.length == 6


  end

  def test_complex_include
    #Students in a university by name
    students = Student.where(enrolled: [university: [name: "Stanford"]], 
                  include: [:name, enrolled: [:name, university: [ :address ]]] )

    assert students.map { |x| x.name }.sort == ["Daniel","John","Susan"]
    students.each do |s|
      s.enrolled do |p|
        assert_instance_of String, p.name
        assert_instance_of University, p.university
        assert_instance_of Array, p.university.addresses
        assert_instance_of Address, p.university.addresses.first
        assert_raises Goo::Base::AttributeNotLoaded do 
          p.university.addresses.first.country
        end
      end
    end
  end

  def test_where_join_pattern
    #students in two programs from soton and stanford
    pattern = Goo::Base::Pattern.new(category: [ code: "Biology" ])
            .join(category: [ code: "Chemistry" ])
    #louis ok
    students = Student.where(enrolled: pattern)
    assert students.map { |x| x.id.to_s } == ["http://goo.org/default/student/Louis"] 


    pattern = Goo::Base::Pattern.new(category: [ code: "Mathematics" ])
            .join(category: [ code: "Engineering" ])
    #daniel, robert, tim and john ok
    students = Student.where(enrolled: pattern)
    assert students.map { |x| x.id.to_s }.sort == ["http://goo.org/default/student/Daniel",
    "http://goo.org/default/student/John","http://goo.org/default/student/Robert",
    "http://goo.org/default/student/Tim"] 


    pattern = Goo::Base::Pattern.new(category: [ code: "Mathematics" ])
            .join(category: [ code: "Medicine" ])
    #daniel ko. a program with both categories not a student with both categories
    #no one
    students = Student.where(enrolled: pattern)
    assert students.length == 0

  end

  def test_where_join_3patterns
    #students in two programs from soton and stanford
    pattern = Goo::Base::Pattern.new(category: [ code: "Biology" ])
            .join(category: [ code: "Chemistry" ])
            .join(category: [ code: "Biology"])

    #louis ok
    students = Student.where(enrolled: pattern)
    assert students.map { |x| x.id.to_s } == ["http://goo.org/default/student/Louis"] 

  end

  def test_where_join_pattern_direct
    #students in programs with engineering and medicine
    #Daniel is in two programs one has medicine (Bioinformatics) and engineering (CompSci)
    pattern = Goo::Base::Pattern.new(enrolled: [ category: [ code: "Chemistry"] ])
                .join(enrolled: [ category: [ code: "Engineering"] ])

    students = Student.where(pattern)
    students.map { |x| x.id.to_s } == ["http://goo.org/default/student/Daniel"]
  end

  def test_where_union_pattern
    #programs in medicine or engineering
    pattern = Goo::Base::Pattern.new(code: "Medicine")
                      .union(code: "Engineering")
    prs = Program.where(category: pattern)
    #all of them 9
    assert prs.length == 9
   
    #programs in medicine or engineering
    pattern = Goo::Base::Pattern.new(code: "Medicine")
                      .union(code: "Chemistry")
    prs = Program.where(category: pattern)
    prs.each do |p|
      assert p.id.to_s["BioInformatics"] || p.id.to_s["Medicine"]
    end
    assert prs.length == 6

    #equivalent but now the triples get gathere in the union
    pattern = Goo::Base::Pattern.new(category: [code: "Medicine"])
                .union(category: [code: "Chemistry"])
    prs = Program.where(pattern: pattern)
    prs.each do |p|
      assert p.id.to_s["BioInformatics"] || p.id.to_s["Medicine"]
    end
    assert prs.length == 6

  end

  def test_where_union_direct
    #students named Daniel or Susan
    pattern = Goo::Base::Pattern.new(name: "Daniel")
                .union(name: "Susan")

    st = Student.where(pattern,include: [:name])
    assert st.length == 2
    assert st.first.name != st[1].name
    st.each do |p|
      assert (p.name == "Susan" || p.name == "Daniel")
    end
  end

  def test_combine_where_patterns
    pattern = Goo::Base::Pattern.new(name: "Daniel")
                .union(name: "Susan")
    st = Student.where(pattern, enrolled: [ category: [ code: "Medicine" ]], 
                          include: [ :name, enrolled: [ university: [ address: [ :country]]]])
    assert st.length == 2
    assert st.first.name != st[1].name
    st.each do |p|
      assert (p.name == "Susan" || p.name == "Daniel")
      assert Array, p.enrolled
      assert (p.name == "Susan" && p.enrolled.length == 1) || 
        (p.name == "Daniel" && p.enrolled.length == 2) 
      assert String, p.enrolled.first.university.address.first.country
    end
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
