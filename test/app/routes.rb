require 'sinatra'
require_relative 'models'
require_relative 'bioportal'

#it sets the databas
get '/census/set' do
  graph = RDF::URI.new(Test::Models::DATA_ID)

  database = Test::Models::Database.new
  database.id = graph
  database.name = "Census tiger 2002"
  database.save

  ntriples_file_path = "../data/TGR06001.nt"

  result = Goo.sparql_data_client.put_triples(
                        graph,
                        ntriples_file_path,
                        mime_type="application/x-turtle")

  "Census database created"
end

get '/census/unset' do
  graph = RDF::URI.new(Test::Models::DATA_ID)
  result = Goo.sparql_data_client.delete_graph(graph)
  database = Test::Models::Database.find(RDF::URI.new(Test::Models::DATA_ID)).first
  database.delete if database
  "Census database deleted"
end

get '/census/pages' do
  db = Test::Models::Database.find(RDF::URI.new(Test::Models::DATA_ID)).first
  page = Test::Models::Line.in(db).page(4,500).include(:start,:end).all
  "Found page with #{page.length} elements"
end

get '/census/find' do
  db = Test::Models::Database.find(RDF::URI.new(Test::Models::DATA_ID)).first
  ids = ["http://www.census.gov/tiger/2002/tlid/124992929",
  "http://www.census.gov/tiger/2002/tlid/124989493",
  "http://www.census.gov/tiger/2002/tlid/124988154",
  "http://www.census.gov/tiger/2002/tlid/124993351",
  "http://www.census.gov/tiger/2002/tlid/124993351"]
  ids[0..0].each do |id|
    res_id = RDF::URI.new(id) 
    l = Test::Models::Line.find(res_id).in(db).first
    reply 500 if l.nil?
    l = Test::Models::Line.find(res_id).in(db).include(:start,:end).first
    reply 500 if l.nil?
  end
  "Find profile completed"
end
