require 'grape'
require 'grape_on_rails_routes'
require 'grape-entity'
require 'grape_api/pagination/configuration'
require 'grape_api/endpoint/base'
require "grape_api/version"
require "grape_api/engine"
require 'active_support/core_ext/module'

module GrapeAPI

  mattr_accessor :pagination
  @@pagination = GrapeAPI::Pagination

  mattr_accessor :base_api_class
  @@base_api_class = "API::Base"

  def self.config
    yield(self)
  end

end

require 'grape_api/hooks'