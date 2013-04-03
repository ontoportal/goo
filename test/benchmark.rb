require 'benchmark'
require_relative 'test_case'

TestInit.configure_goo

MULT_VALS = 1
SING_VALS = 30
INT_VALS = 5
DATE_VALS = 5
DEP_OBJ = 1

INSTANCES = 100

#One model with 100 attributes to stree the system
class BenchmarkModel < Goo::Base::Resource
  def initialize(attributes = {})
    super(attributes)
  end

  model :benchmark_model

  #a key attribute
  attribute :name, :unique => true

  MULT_VALS.times do |i|
    attribute "attr_#{i}"
  end
  SING_VALS.times do |i|
    attribute "attr_sinval_#{i}", :single_value => true
  end
  INT_VALS.times do |i|
    attribute "attr_intval_#{i}", :single_value => true, :instance_of => { :with => Fixnum }
  end
  DATE_VALS.times do |i|
    attribute "attr_dateval_#{i}", :single_value => true, :date_time_xsd => true
  end
  DEP_OBJ.times do |i|
    attribute "attr_depobj_#{i}", :instance_of => :benchmark_model
  end
end

class TestBenchmarkModel < TestCase

  def initialize(*args)
    super(*args)
  end

  def delete(bench)
    if bench
      rep = bench.report("delete:") do
        instance = BenchmarkModel.all.each do |b|
          b.delete
        end
      end
      puts "delete: %.3f instances/sec."%(INSTANCES/rep.total)
    else
      instance = BenchmarkModel.all.each do |b|
        b.delete
      end
    end
  end

  def create(bench)
    rep = bench.report("create:") do
      INSTANCES.times do |i|
        data = Hash.new
        data["name"] = "name#{i}"
        MULT_VALS.times do |ai|
          data["attr_#{ai}"] = ["val0" * 5, "val1" * 50]
        end
        SING_VALS.times do |ai|
          data["attr_sinval_#{ai}"] = "sing value" * 10
        end
        INT_VALS.times do |ai|
          data["attr_intval_#{ai}"] = 123456789
        end
        DATE_VALS.times do |ai|
          data["attr_dateval_#{ai}"] = DateTime.now
        end
        instance = BenchmarkModel.new data
        instance.save
      end
    end
    puts "create: %.3f instances/sec."%(INSTANCES/rep.total)
  end

  def pages(bench)
    some_attrs =  { :name => true,
                    :attr_0 => true,
                    :attr_sinval_0 =>true,
                    :attr_sinval_1 =>true,
                    :attr_intval_0 => true,
                    :attr_intval_1 => true,
                    :attr_dateval_0 => true,
                    :attr_dateval_1 => true
                  }

    page_count = 0
    rep = bench.report("page all attrs:") do
      page = 1
      while page
        page_model = BenchmarkModel.page page: page
        page = page_model.next_page
        page_count = page_model.page_count
      end
    end
    puts "page all attrs: %.3f pages/sec."%(page_count/rep.total)
    rep = bench.report("page some attrs:") do
      page = 1
      while page
        page_model = BenchmarkModel.page page: page,
                           load_attrs: some_attrs
        page = page_model.next_page
      end
    nthreads = 6
    $THREADS = []
    result = Benchmark.measure do 
          bt = Time.now
          et = Time.now
        end
      }.each(&:join)
    end
    puts result 
  end

  def calculate_percentile(array, percentile)
    array.sort[(percentile * array.length).ceil - 1]
  end

  def stats(arr)
    avg = arr.inject{ |sum, el| sum + el }.to_f / arr.size
    sum = arr.inject{ |sum, el| sum + el }.to_f 
    max = arr.max
    perc85 = calculate_percentile(arr,0.85)
    return "%.3f %.3f %.3f %.3f %d"%[avg, max, perc85,sum,arr.length]
  end

  def stats4s(f)
    arr = []
    f = File.open(f,"r")
    f.each do |n|
      arr << n.to_f
    end
    f.close()
    puts stats(arr)
  end

  def test_benchmark
    delete(nil)
    Benchmark.bm(1) do |bench|
      create(bench)
      pages(bench)
      delete(bench)
    end
  end


end
