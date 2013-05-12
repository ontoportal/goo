require_relative 'test_case'
require_relative 'test_where'

GooTest.configure_goo

module TestReadOnly

  class TestReadOnlyWithStruct < TestWhere

    def initialize(*args)
      super(*args)
    end

    def setup
    end

    def test_struct
      students = Student.where(enrolled: [university: [name: "Stanford"]])
                .include(:name)
                .read_only
                .all
      students.each do |st|
        st.klass= Student
        assert st.name
        assert st.is_a?Struct
        assert st.id.class == RDF::URI
      end
    end
    def test_embed_struct
      skip "not yet supported"

      students = Student.where(enrolled: [university: [name: "Stanford"]])
                .include(:name)
                .include(enrolled: [:name, university: [ :address ]]).all
      binding.pry
    end
  end
end
