require 'grape_api/resourceful/resource'
require 'grape_api/resourceful/responder'

module GrapeAPI
  module Resourceful

    def self.included base
      base.include Responder
      base.include Resource
    end

  end
end