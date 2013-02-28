class Fixnum
  alias in_eql? eql?
  alias in_eql_sym ==
  alias cmp_int_orig <=>
  alias cmp_intl_orig <
  alias cmp_intg_orig >
  alias cmp_intle_orig <=
  alias cmp_intge_orig >=

  def eql?(other)
    if other.kind_of? SparqlRd::Resultset::IntegerLiteral
      return in_eql?(other.parsed_value)
    end
    return in_eql?(other)
  end

  def ==(other)
   if other.kind_of? SparqlRd::Resultset::IntegerLiteral
      return in_eql_sym(other.parsed_value)
    end
    return in_eql_sym(other)
  end

  def <=>(other)
    other = other.parsed_value if other.instance_of? SparqlRd::Resultset::IntegerLiteral
    return cmp_int_orig(other)
  end
  def <(other)
    other = other.parsed_value if other.instance_of? SparqlRd::Resultset::IntegerLiteral
    return cmp_intl_orig(other)
  end
  def >(other)
    other = other.parsed_value if other.instance_of? SparqlRd::Resultset::IntegerLiteral
    return cmp_intg_orig(other)
  end
  def >=(other)
    other = other.parsed_value if other.instance_of? SparqlRd::Resultset::IntegerLiteral
    return cmp_intge_orig(other)
  end
  def <=(other)
    other = other.parsed_value if other.instance_of? SparqlRd::Resultset::IntegerLiteral
    return cmp_intle_orig(other)
  end
end
