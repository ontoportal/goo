require_relative '../test_case'

module Test
  module Models

    DATA_ID = "http://www.census.gov/tiger/2002/"

    class Database < Goo::Base::Resource
      model :database, name_with: lambda { |k| k.id }
      attribute :name
    end 

    LatLongTuple = Struct.new(:tiger_lat,:tiger_long)
    class Line < Goo::Base::Resource
      model :line, namespace: :tiger, name_with: lambda { |k| k.id },
              collection: :db
      attribute :db, enforce: [ :database ]
      attribute :start, namespace: :tiger, enforce: [ LatLongTuple ]
      attribute :end, namespace: :tiger, enforce: [ LatLongTuple ]
    end

  end
end
