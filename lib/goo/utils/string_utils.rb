
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
end

