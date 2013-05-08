require_relative 'test_case'

GooTest.configure_goo

class TestWhere < MiniTest::Unit::TestCase

  def initialize(*args)
    super(*args)
  end

  def setup
  end

  def self.before_suite
  end

  def self.after_suite
  end

  def test_include_schemaless
  end
end
