require "benchmark"
require "csv"

require_relative '../test_case'
require_relative './query_profiler'

module Test
  module BioPortal 
    class Ontology < Goo::Base::Resource
      model :ontology, namespace: :bioportal, name_with: :acronym
      attribute :acronym, namespace: :omv, enforce: [:existence, :unique]
      attribute :name, namespace: :omv, enforce: [:existence]
      attribute :administeredBy, enforce: [:user, :existence]
    end 

    class User < Goo::Base::Resource
      model :user, name_with: :username
      attribute :username, enforce: [:existence, :unique]
      attribute :email, enforce: [:existence, :email]
      attribute :roles, enforce: [:list, :role, :existence]
      attribute :created, enforce: [ DateTime ],
                default: lambda { |record| DateTime.now }
      attribute :notes, inverse: { on: :note, attribute: :owner}
    end 

    class Role < Goo::Base::Resource
      model :role, :inmutable, name_with: :code
      attribute :code, enforce: [:existence, :unique]
      attribute :users, inverse: { on: :user, attribute: :roles }
    end

    class Note < Goo::Base::Resource
      model :note, name_with: lambda { |s| id_generator(s) }  
      attribute :content, enforce: [:existence]
      attribute :ontology, enforce: [:existence, :ontology]
      attribute :owner, enforce: [:existence, :user]
      def self.id_generator(inst)
        return RDF::URI.new("http://example.org/note/" + inst.owner.username + "/" + Random.rand(1000000).to_s )
      end
    end

    def self.benchmark_data
    Goo.sparql_query_client.reset_profiling
    if false
      10.times do |i|
        Role.new(code: "role#{i}").save
      end
      puts "Roles created"
      900.times do |i|
        roles = []
        2.times do |j|
           roles << Role.find("role#{j}").first
        end
        u = User.new(username: "user#{i}name", email: "email#{i}@example.org", roles: roles)
        u.save
        puts "#{i} users created"
      end
      400.times do |i|
        ont = Ontology.new(acronym: "ontology #{i}",name: "ontology ontology ontology #{i}")
        ont.administeredBy = User.find("user#{i % 75}name").first
        ont.save
      end
      binding.pry
      1000.times do |i|
        ont = Ontology.where(acronym: "ontology #{Random.rand(200)}").all.first
        owner = User.where(username: "user#{i % 300}name").include(:username).all.first
        n = Note.new(content: "content " * 60, owner: owner, ontology: ont)
        n.save
        puts "created note #{i}"
      end
      binding.pry
      2000.times do |i|
        ont = Ontology.where(acronym: "ontology #{Random.rand(15)}").all.first
        owner = User.where(username: "user#{i % 200}name").include(:username).all.first
        n = Note.new(content: "content " * 60, owner: owner, ontology: ont)
        n.save
        puts "created note #{i}"
      end
      binding.pry
      800.times do |i|
        ont = Ontology.where(acronym: "ontology #{Random.rand(6)}").all.first
        owner = User.where(username: "user#{i % 200}name").include(:username).all.first
        n = Note.new(content: "content " * 60, owner: owner, ontology: ont)
        n.save
        puts "created note #{i}"
      end
    end
      500.times do |i|
        ont_id = 0
        begin
          ont_id = Random.rand(5)+180
        end
        ont = Ontology.where(acronym: "ontology #{ont_id}").all.first
        owner = User.where(username: "user#{i % 200}name").include(:username).all.first
        n = Note.new(content: "content " * 60, owner: owner, ontology: ont)
        n.save
        puts "created note #{i}"
      end
    end

        def self.benchmark_naive_query
      Goo.sparql_query_client.reset_profiling
      ont = Ontology.where.include(:acronym).all
      bench_result = []
      ont.each do |ont|
        qq =<<eos
        SELECT *
    WHERE { ?id a <http://goo.org/default/User> .
        ?id <http://goo.org/default/username> ?username .
        ?id <http://goo.org/default/email> ?email .
        ?note <http://goo.org/default/owner> ?id .
        ?note <http://goo.org/default/content> ?content .
        ?note <http://goo.org/default/ontology> ?ontology .
        ?ontology <http://omv.org/ontology/acronym> ?acronym .
        ?ontology <http://omv.org/ontology/name> ?ont_name .
        ?id <http://goo.org/default/roles> ?roles .
        ?roles <http://goo.org/default/code> ?code .
    FILTER (?acronym = "#{ont.acronym}")}
eos

        count_sol = 0
        notes = {}
        q_time = 0
        client = Goo.sparql_query_client
        client.reset_profiling
        start = Time.now
        notes = {}
        users = {}
        roles = {}
        count_sol = 0
        res = client.query(qq) 
        res.each do |sol|
          unless users.include?(sol[:id])
            users[sol[:id]] = User.new
            users[sol[:id]].username=sol[:username]
            users[sol[:id]].email=sol[:email]
          end
          unless roles.include?(sol[:roles])
            roles[sol[:roles]] = Role.new
            roles[sol[:roles]].code = sol[:code]
          end
          unless notes.include?(sol[:note])
            notes[sol[:note]] = Note.new
            notes[sol[:note]].owner = users[sol[:id]]
          end
          count_sol = count_sol + 1
        end
        bench_result << [Time.now - start,notes.length, client.query_times.last, client.parse_times.last,count_sol ]
      end
      bench_result.select! { |x| x[1] > 0 }
      bench_result.sort_by! { |x| x[1] }
      CSV.open("benchmark_naive.csv", "wb") do |csv|
        csv << ["total", "notes", "qt", "pt","sol"]
        bench_result.each do |b|
          csv <<  b
        end
      end
    end

    def self.benchmark_naive_fast
      Goo.sparql_query_client.reset_profiling
      ont = Ontology.where.include(:acronym).all
      bench_result = []
      ont.each do |ont|
        qq =<<eos
        SELECT ?id ?note ?content
    WHERE { ?id a <http://goo.org/default/User> .
        ?note <http://goo.org/default/owner> ?id .
        ?note <http://goo.org/default/content> ?content .
        ?note <http://goo.org/default/ontology> ?ontology .
        ?ontology <http://omv.org/ontology/acronym> ?acronym .
        ?ontology <http://omv.org/ontology/name> ?ont_name .
    FILTER (?acronym = "#{ont.acronym}")}
eos

        count_sol = 0
        notes = {}
        q_time = 0
        client = Goo.sparql_query_client
        client.reset_profiling
        start = Time.now
        notes = {}
        users = {}
        roles = {}
        count_sol = 0
        res = client.query(qq) 
        res.each do |sol|
          unless users.include?(sol[:id])
            users[sol[:id]] = User.new
            users[sol[:id]].username=sol[:username]
          end
          unless roles.include?(sol[:roles])
            roles[sol[:roles]] = Role.new
            roles[sol[:roles]].code = sol[:code]
          end
          unless notes.include?(sol[:note])
            notes[sol[:note]] = Note.new
            notes[sol[:note]].owner = users[sol[:id]]
          end
          count_sol = count_sol + 1
        end
        bench_result << [Time.now - start,notes.length, client.query_times.last, client.parse_times.last,count_sol ]
      end
      bench_result.select! { |x| x[1] > 0 }
      bench_result.sort_by! { |x| x[1] }
      CSV.open("benchmark_naive_fast.csv", "wb") do |csv|
        csv << ["total", "notes", "qt", "pt","sol"]
        bench_result.each do |b|
          csv <<  b
        end
      end
    end

    def self.benchmark_query_goo_fast
      client = Goo.sparql_query_client
      client.reset_profiling
      ont = Ontology.where.include(:acronym).all
      bench_result = []
      ont.each do |ont|
        client.reset_profiling
        start = Time.now
        notes = nil
        notes = Note.where(ontology: ont)
          .include(:content)
          .include(:owner)
          .all
        num_queries = client.query_times.length
        agg_parsing = client.parse_times.inject{|sum,x| sum + x }
        agg_queries = client.query_times.inject{|sum,x| sum + x }
        bench_result << [Time.now - start, notes.length,agg_queries,agg_parsing,num_queries ]
      end
      bench_result.select! { |x| x[1] > 0 }
      bench_result.sort_by! { |x| x[1] }
      CSV.open("benchmark_goo_fast.csv", "wb") do |csv|
        csv << ["total", "notes", "agg_qt", "agg_qp", "queries"]
        bench_result.each do |b|
          csv <<  b
        end
      end
    end

    def self.benchmark_query_goo
      client = Goo.sparql_query_client
      client.reset_profiling
      ont = Ontology.where.include(:acronym).all
      bench_result = []
      Role.load_inmutable_instances
      ont.each do |ont|
        client.reset_profiling
        start = Time.now
        notes = nil
        notes = Note.where(ontology: ont)
          .include(:content)
          .include(owner: [ :username, :email, roles: [:code]])
          .read_only
          .all
        num_queries = client.query_times.length
        agg_parsing = client.parse_times.inject{|sum,x| sum + x }
        agg_queries = client.query_times.inject{|sum,x| sum + x }
        bench_result << [Time.now - start, notes.length,agg_queries,agg_parsing,num_queries ]
      end
      bench_result.select! { |x| x[1] > 0 }
      bench_result.sort_by! { |x| x[1] }
      CSV.open("benchmark_goo.csv", "wb") do |csv|
        csv << ["total", "notes", "agg_qt", "agg_qp", "queries"]
        bench_result.each do |b|
          csv <<  b
        end
      end
    end

    def self.benchmark_all
      benchmark_naive_fast
      benchmark_naive_query
      benchmark_query_goo_fast
      benchmark_query_goo
    end
  end
end
