# sinatra-base
require 'sinatra'

# Require middleware
require 'rack/accept'
require 'rack/post-body-to-params'
require 'pry'

require_relative '../../lib/goo.rb'
require_relative 'routes.rb'
require 'rack-mini-profiler'

use Rack::MiniProfiler
use Rack::Accept
use Rack::PostBodyToParams

#Rack::MiniProfiler.profile_method SPARQL::Client, "response"
#Rack::MiniProfiler.profile_method SPARQL::Client, "parse_response"
Rack::MiniProfiler.config.skip_paths = ["/favicon.ico"]
