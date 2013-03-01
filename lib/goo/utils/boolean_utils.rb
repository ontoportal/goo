class TrueClass
  alias tr_eql? eql?
  alias tr_eql_sym ==

  def eql?(other)
    if other.kind_of? SparqlRd::Resultset::BooleanLiteral
      return tr_eql?(other.parsed_value)
    end
    return tr_eql?(other)
  end

  def ==(other)
   if other.kind_of? SparqlRd::Resultset::BooleanLiteral
      return tr_eql_sym(other.parsed_value)
    end
    return tr_eql_sym(other)
  end
end
class FalseClass
  alias fl_eql? eql?
  alias fl_eql_sym ==

  def eql?(other)
    if other.kind_of? SparqlRd::Resultset::BooleanLiteral
      return fl_eql?(other.parsed_value)
    end
    return fl_eql?(other)
  end

  def ==(other)
   if other.kind_of? SparqlRd::Resultset::BooleanLiteral
      return fl_eql_sym(other.parsed_value)
    end
    return fl_eql_sym(other)
  end
end
