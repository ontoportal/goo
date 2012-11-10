require "pry"
require "sparql_http"

require "active_model"
require "ostruct"
require "set"
require "uri"

require_relative "goo/validators/validators"
require_relative "goo/base/base"
require_relative "goo/naming/naming"
require_relative "goo/utils/utils"

module Goo 

  @@_configuration = {}
  @@_default_store = nil

  def self.configure
    raise ArgumentError, "Configuration needs to receive a code block" \
      if not block_given?

    yield @@_configuration
    raise ArgumentError, "Store configuration not found in configuration" \
      unless @@_configuration.has_key? :stores
    stores = @@_configuration[:stores]
    stores.each do |store|
      SparqlRd::Repository.configuration(store)
      if store.has_key? :default and store[:default]
        @@_default_store  = SparqlRd::Repository.endpoint(store[:name])
      end
    end
    @@_default_store = SparqlRd::Repository.endpoint(stores[0][:name]) \
      if @@_default_store.nil?
  end

  def self.store(name=nil)
    if name.nil?
      return @@_default_store
    end
    return SparqlRd::Repository.endpoint(name)
  end

end
