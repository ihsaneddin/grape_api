require 'grape'
require 'active_record'
require 'action_controller'

module GrapeAPI
  module Endpoint
    class Base < Grape::API

      prefix 'api'
      format 'json'
      version cascade: false

      helpers do
        def logger
          Rails.logger
        end
      end

      #
      # catch active record not found exception
      # catch ActiveRecord::NoDatabaseError exception
      #
      rescue_from ::ActiveRecord::RecordNotFound, ActiveRecord::NoDatabaseError do |e|
        error_response(message: "Record not found", status: 404)
      end

      # rescue_from ::ActionController::RoutingError do |e|
      #   error_response(message: "Route not found", status: 404)
      # end

      #
      # catch active record invalid exception
      #
      rescue_from ::ActiveRecord::RecordInvalid do |e|
        error_response(message: e.message, status: 422)
      end

      #
      # catch bad request exception
      #
      # rescue_from ::ActionController::ParameterMissing, ::ActiveRecord::Rollback do |e|
      #   error_response(message: e.message, status: 400)
      # end

      # #
      # # catch action controller parameter missing
      # #
      # rescue_from ::ActionController::ParameterMissing do |e|
      #   error_response(message: e.message, status: 422)
      # end

      #
      # catch Grape::Exceptions::ValidationErrors exception
      # catch Grape::Exceptions::MethodNotAllowed
      #
      rescue_from Grape::Exceptions::ValidationErrors, Grape::Exceptions::MethodNotAllowed do |e|
        error_response(message: e.message, status: 405)
      end

      #
      # rescue from all others exception
      #
      rescue_from :all do |e|
        if !Rails.env.production?
          raise e
        else
          error_response(message: e.message, status: 500)
        end
      end

      # Generate a properly formatted 404 error for all unmatched routes except '/'
      route :any, '*path' do
        error_response(message: "Not found", details: "No such route '#{request.path}'", status: 404)
      end

      # Generate a properly formatted 404 error for '/'
      route :any do
        error_response(message: "Not found", details: "No such route '#{request.path}'", status: 404)
      end

    end
  end
end