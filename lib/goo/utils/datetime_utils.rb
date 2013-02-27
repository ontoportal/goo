class DateTime
  alias dt_eql? eql?
  alias dt_eql_sym ==
  alias cmp_dt_orig <=>

  def eql?(other)
    if other.kind_of? SparqlRd::Resultset::DatetimeLiteral
      return dt_eql?(other.parsed_value)
    end
    return dt_eql?(other)
  end
  def ==(other)
   if other.kind_of? SparqlRd::Resultset::DatetimeLiteral
      return dt_eql_sym(other.parsed_value)
    end
    return dt_eql_sym(other)
  end
  def <=>(other)
    other = other.parsed_value if other.instance_of? SparqlRd::Resultset::DatetimeLiteral
    return cmp_dt_orig(other)
  end
end
