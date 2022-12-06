module GrapeAPI
  module Resourceful
    module Resource

      def self.included base
        base.class_eval do
          class_attribute :resourceful_params_
          self.resourceful_params_ = {}
        end
        base.extend ClassMethods
        ::Grape::Endpoint.include HelperMethods if defined? ::Grape::Endpoint
      end

      module ClassMethods

        def resourceful_params key=nil
          if self.resourceful_params_[self.to_s].blank?
            self.resourceful_params_[self.to_s] = {
              model_klass: nil,
              resource_identifier: nil,
              resource_finder_key: nil,
              resource_params_key: nil,
              resource_params_attributes: [],
              resource_friendly: false,
              query_includes: nil,
              query_scope: nil,
              resource_actions: [ :show, :new, :create, :edit, :update, :destroy ],
              collection_actions: [ :index ],
              got_resource_callback: nil,
              should_paginate: true,
            }
          end
          if(key)
            return self.resourceful_params_[self.to_s][key]
          else
            return self.resourceful_params_[self.to_s]
          end
        end

        def resourceful_params_merge! opts = {}
          current_opts = resourceful_params
          current_opts = current_opts.merge!(opts)
          self.resourceful_params_[self.to_s] = current_opts
        end

        def set_resource_param key, value
          self.resourceful_params_[self.to_s][key] = value
        end

        def fetch_resource_and_collection!(resourceful_params = {}, &block)
          fetch_resource! resourceful_params, &block
          fetch_collection! resourceful_params, &block
        end

        def fetch_resource!(resourceful_params = {}, &block)
          resourceful_params_merge!(resourceful_params)
          yield if block_given?
          context = self
          after_validation do
            unless route.settings[:skip_resource]
              _set_resource(context)
            end
          end
        end

        def fetch_collection!(resourceful_params = {}, &block)
          resourceful_params_merge!(resourceful_params)
          yield if block_given?
          context = self
          after_validation do
            unless route.settings[:skip_collection]
              _set_collection(context)
            end
          end
        end

        def actions(kind: :resource, only: [], except: [], also: [])
          kind = (kind.to_s + '_actions').to_sym
          current_params = resourceful_params
          current_params[kind] = current_params[kind].filter{ |action| only.is_a?(Array) ? only.include?(action) : only.to_s.eql?(action.to_s) } unless only.empty?
          current_params[kind] = current_params[kind].filter{ |action| except.is_a?(Array) ? !except.include?(action) : !except.to_s.eql?(action.to_s) } unless except.empty?
          current_params[kind] = (current_params[kind] + also).flatten.uniq unless also.empty?
          resourceful_params_merge!(current_params)
          current_params[kind]
        end

        def resource_actions
          resourceful_params[:resource_actions]
        end

        def collection_actions
          resourceful_params[:collection_actions]
        end

        def model_klass(klass = nil)
          klass = resourceful_params[:model_klass] if klass.nil?
          if klass.nil?
            klass = self.to_s.demodulize.singularize.camelcase
          end
          set_resource_param :model_klass, klass
          klass
        end

        def model_klass_constant
          if class_exists?(model_klass)
            model_klass.constantize
          else
            model_klass.constantize
          end
        rescue
          raise { ActiveRecord::RecordNotFound }
        end

        def attributes &block
          params &block
        end

        def class_exists?(klass)
          klass = Module.const_get(klass)
          klass.is_a?(Class) && klass < ActiveRecord::Base
        rescue NameError
          false
        end

        def query_includes(includes = nil)
          current_params = resourceful_params
          includes = current_params[:query_includes] if includes.nil?
          set_resource_param(:query_includes, includes) unless includes.nil?
          includes
        end

        def query_scope(query = nil)
          query = resourceful_params(:query_scope) if query.nil?
          query = model_klass_constant if query.nil?
          set_resource_param(:query_scope, query)
          #query.respond_to?(:call) ? query.call(model_klass_constant) : query
          query
        end

        def resource_identifier(identifier = nil)
          if identifier.nil?
            identifier = resourceful_params(:resource_identifier)
            if(identifier.nil?)
              identifier = model_klass_constant.primary_key
              set_resource_param(:resource_identifier, identifier)
            end
          else
            set_resource_param(:resource_identifier, identifier)
          end
          identifier
        end

        def resource_finder_key(key = nil)
          key = resourceful_params(:resource_finder_key) if key.nil?
          if key.nil?
            key = model_klass_constant.primary_key
            set_resource_param(:resource_finder_key, key)
          else
            set_resource_param(:resource_finder_key, key)
          end
          key
        end

        def resource_identifier_and_finder_key identifier
          resource_identifier identifier
          resource_finder_key identifier
        end

        def resource_params_key(key = nil)
          if key.nil?
            key = resourceful_params(:resource_params_key)
            if(key.nil?)
              key = model_klass.underscore.downcase.to_sym
              set_resource_param(:resource_params_key, key)
            end
          else
            set_resource_param(:resource_params_key, key)
          end
          key
        end

        def resource_params_attributes(*attributes)
          if attributes.empty?
            attributes = resourceful_params(:resource_params_attributes)
          end
          unless attributes.empty?
            set_resource_param(:resource_params_attributes, attributes)
          end
          attributes
        end

        def resource_friendly?(friendly = nil)
          friendly = resourceful_params[:resource_friendly] if friendly.nil?
          if friendly.nil?
            set_resource_param(:resource_friendly, false)
          end
          set_resource_param(:resource_friendly, friendly)
          friendly
        end

        def got_resource_callback(proc = nil)
          proc = resourceful_params[:got_resource_callback] if proc.nil?
          unless proc.nil?
            set_resource_param(:got_resource_callback, proc)
          end
          proc
        end

        def should_paginate? pg = nil
          pg = resourceful_params[:should_paginate] if pg.nil?
          if pg.nil?
            set_resource_param(:should_paginate, false)
          end
          set_resource_param(:should_paginate, pg)
          pg
        end

      end

      module HelperMethods

        def permitted_params
          @permitted_params ||= declared(params, include_missing: false, include_parent_namespaces: false)
        end

        def _set_resource(context)
          return unless @_resource.nil?
          _define_context(context)
          var_name = class_context do |context|
            context.model_klass.demodulize.underscore.downcase
          end
          @_resource = _get_resource
          instance_variable_set("@#{var_name}", @_resource)
        end

        def _get_resource
          got_resource = _identifier_param_present? ? _existing_resource : _new_resource
          if (class_context do |context|
                context.got_resource_callback.respond_to?(:call)
              end)
            got_resource_callback = class_context do |context| context.got_resource_callback end
            instance_exec(got_resource, &got_resource_callback)
          end
          got_resource
        end

        def _identifier_param_present?
          if context= class_context
            identifier = context.resource_identifier
            if identifier.respond_to?(:call)
              identifier = instance_exec(&identifier)
            end
            params[identifier.to_sym].present?
          end
        end

        def _new_resource
          if(class_context)
            class_context.model_klass_constant.new _resource_params
          end
        end

        def model_class_constant
          class_context.model_klass_constant
        end

        def posts
          @strong_parameter_object ||= ActionController::Parameters.new(params)
        end

        def permitted_attributes
          _resource_params
        end

        def _resource_params
          attributes = {}
          if(class_context)
            # if params[class_context.resource_params_key].present?
            attributes  = permitted_params
            if attributes.empty?
              if posts.present?
                # attributes = params.require(class_context.resource_params_key)
                if class_context.resource_params_attributes.empty?
                  attributes = {}
                else
                  _resource_params_attributes_ = class_context.resource_params_attributes
                  if _resource_params_attributes_[0].is_a?(Proc)
                    _resource_params_attributes_ = instance_exec(&_resource_params_attributes_[0])
                  end
                  attributes = posts.permit(_resource_params_attributes_)
                end
              end
            end
          end
          attributes
        end

        def _apply_query_includes query
          unless class_context.query_includes.blank?
            includes = class_context.query_includes
            if includes.is_a?(Array)
              query = query.includes(*class_context.query_includes)
            else
              query = query.includes(class_context.query_includes)
            end
          end
          query
        end

        def _query
          if(class_context)
            query = class_context.query_scope
            if query.respond_to?(:call)
              model = _apply_query_includes(model_class)
              query = instance_exec(model, &query)
            else
              query = _apply_query_includes(query)
              query = query.where.not id: nil
            end
            if(params[:order_by])
              query = query.order params[:order_by]
            end
            if(params[:distinct])
              query = query.group(params[:distinct])
            end
            query
          end
        end

        def model_class
          class_context.model_klass_constant
        end

        def _identifier
          if class_context
            id = class_context.resource_identifier
            if(id.respond_to?(:call))
              id = instance_exec &id
            end
            id = id.is_a?(String)? id.to_sym : id
            if id.is_a? Symbol
              finder_key = class_context.resource_finder_key
              if finder_key.respond_to? :call
                finder_key = instance_exec(&finder_key)
              end
              par = { "#{finder_key}": params[id] }
              if class_context.resource_friendly? && class_context.model_klass_constant.included_modules.include?("FriendlyId::Slugged")
                par[id]
              else
                par
              end
            elsif id.is_a? Array
              Hash[id.map { |i| [i, params[i]] }]
            else
              {}
            end
          end
        end

        def _existing_resource
          if class_context
            if class_context.resource_friendly? && class_context.model_klass_constant.included_modules.include?("FriendlyId::Slugged")
              resource = _query.friendly.find(_identifier)
            else
              resource = _query.send('find_by!', _identifier)
            end
            if resource.nil?
              raise ActiveRecord::RecordNotFound
            end
            resource
          end
        end

        def _set_collection(context)
          return unless @_resources.nil?
          _define_context(context)
          var_name = class_context do |context|
            context.model_klass.demodulize.underscore.downcase.pluralize
          end
          @_resources = class_context.should_paginate?? paginate(_get_resources) : _get_resources
          instance_variable_set("@#{var_name}", @_resources)
        end

        def _get_resources
          _query
        end

        def class_context &block
          if self.class.respond_to?(:context) && self.class.context
            block_given?? yield(self.class.context) : self.class.context
          end
        end

        def _define_context(context = null)
          if(context)
            unless self.class.respond_to?(:context)
              self.class.class_eval do
                class_attribute :context
                self.context = context
              end
            end
          end
          self.class.context
        end

        def resources
          var_name = class_context do |context|
            context.model_klass.underscore.pluralize
          end
          return instance_variable_get("@#{var_name}")
        end

        def resource
          var_name = class_context do |context|
            context.model_klass.demodulize.underscore.downcase
          end
          return instance_variable_get("@#{var_name}")
        end

      end

    end
  end
end