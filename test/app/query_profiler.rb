class SPARQL::Client
  attr_accessor :query_times
  attr_accessor :parse_times

  alias_method :response_without_profiling, :response
  def response_with_profiling(query, options = {})
    start = Time.now
    result = response_without_profiling(query, options)
    @query_times << (Time.now - start) if @query_times
    return result
  end

  alias_method :response, :response_with_profiling
  puts "SPARQL::Client.response instrumented for profiling"

  alias_method :parse_response_without_profiling, :parse_response
  def parse_response_with_profiling(data, options = {})
    start = Time.now
    result = parse_response_without_profiling(data, options)
    elapsed_time = ((Time.now - start).to_f * 1000).round(1)
    @parse_times << (Time.now - start)  if @parse_times
    return result
  end

  alias_method :parse_response, :parse_response_with_profiling
  puts "SPARQL::Client.parse_response instrumented for profiling"

  def reset_profiling()
    @query_times = []
    @parse_times = []
  end
end
