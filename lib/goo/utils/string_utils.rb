
class String
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
end
