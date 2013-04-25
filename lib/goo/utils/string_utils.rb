
class String
  alias str_eql? eql?
  alias str_eql_sym ==
  alias cmp_str_orig <=>
  alias plus_orig +

  def underscore
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end
  def camelize
    self.split('_').map {|w| w.capitalize}.join
  end
  def predicate
    ss = self.camelize
    return ss[0].downcase + ss[1..-1]
  end
  def eql?(other)
    if other.kind_of? SparqlRd::Resultset::StringLiteral
      return str_eql?(other.value)
    end
    return str_eql?(other)
  end
  def ==(other)
   if other.kind_of? SparqlRd::Resultset::StringLiteral
      return str_eql_sym(other.value)
    end
    return str_eql_sym(other)
  end
  def <=>(other)
    other = other.parsed_value if other.instance_of? SparqlRd::Resultset::StringLiteral
    return cmp_str_orig(other)
  end
  def +(other)
    other = other.parsed_value if other.instance_of? SparqlRd::Resultset::StringLiteral
    return plus_orig(other)
  end
  def numeric?
    Float(self) != nil rescue false
  end
end

