require_relative 'test_case'

module TestInmutable
  class Status < Goo::Base::Resource
    model :status, :inmutable, name_with: :code
    attribute :code, enforce: [:unique, :existence]
    attribute :description, enforce: [:existence]
  end

  class Person < Goo::Base::Resource
    model :person, :inmutable, name_with: :name
    attribute :name, enforce: [:unique, :existence]
    attribute :status, enforce: [:status, :existence]
  end

  class TestInmutableCase < MiniTest::Unit::TestCase
   def initialize(*args)
      super(*args)
    end

    def setup
    end

    def self.before_suite
      status = ["single", "married", "divorced", "widowed"]
      status.each do |st|
        stt = Status.new(code: st, description: (st + " some desc"))
        stt.save
      end
      people = [
        ["Susan","married"],
        ["Lee","divorced"],
        ["John","divorced"],
        ["Peter","married"],
        ["Christine","married"],
        ["Ana","single"],
      ]
      people.each do |p|
        po = Person.new
        po.name = p[0]
        po.status = Status.find(p[1]).first
        po.save
      end
    end

    def self.after_suite
      objs = [Person,Status]
      objs.each do |obj|
        obj.where.all.each do |st|
          st.delete
        end
      end
    end

    ## TODO inmutable are deprecated - they might come back in a different way"
    def skip_test_inmutable
      #they come fully loaded
      Status.load_inmutable_instances
      status1 = Status.where.all.sort_by { |s| s.code }
      status2 = Status.where.all.sort_by { |s| s.code }
      assert status1.length == 4
      assert status2.length == 4
      #same referencs
      status1.each_index do |i|
        assert status1[i].object_id==status2[i].object_id 
      end

      #create a new object
      stt = Status.new(code: "xx", description: ("xx" + " some desc"))
      stt.save

      status1 = Status.where.all.sort_by { |s| s.code }
      status2 = Status.where.all.sort_by { |s| s.code }
      assert status1.length == 5
      assert status2.length == 5
      #same referencs
      status1.each_index do |i|
        assert status1[i].object_id==status2[i].object_id 
      end 

      status1.each do |st|
        assert st.code
        assert st.description
      end

      marr = Status.find("divorced").first
      assert marr.code == "divorced"
      assert marr.description
      assert marr.object_id == status1.first.object_id

      people = Person.where.include(:name, status: [ :code, :description ]).all
      people.each do |p|
        assert p.status.object_id == status1.select { |st| st.id == p.status.id }.first.object_id
        assert p.status.code
        assert p.status.description
      end
    end

  end
end
