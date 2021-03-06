module GrapeAPI
  module Pagination
    def self.included(base)
      Grape::Endpoint.class_eval do
        def paginate(collection)
          per_page = GrapeAPI.pagination.config.per_page_param(params) || route_setting(:per_page)

          options = {
            :page     => GrapeAPI.pagination.config.page_param(params),
            :per_page => [per_page, route_setting(:max_per_page)].compact.min
          }
          collection, pagy = GrapeAPI::Pagination.paginate(collection, options)
          links = (header['Link'] || "").split(',').map(&:strip)
          url   = request.url.sub(/\?.*$/, '')
          pages = GrapeAPI::Pagination.pages_from(pagy || collection, options)

          pages.each do |k, v|
            old_params = Rack::Utils.parse_nested_query(request.query_string)
            new_params = old_params.merge('page' => v)
            links << %(<#{url}?#{new_params.to_param}>; rel="#{k}")
          end

          total    = GrapeAPI.pagination.config.total
          per_page = GrapeAPI.pagination.config.per_page
          page     = GrapeAPI.pagination.config.page
          include_total   = GrapeAPI.pagination.config.include_total

          header 'Link',          links.join(', ') unless links.empty?
          header total,    GrapeAPI::Pagination.total_from(pagy || collection).to_s if include_total
          header per_page, options[:per_page].to_s
          header page,     options[:page].to_s unless page.nil?

          return collection
        end
      end

      base.class_eval do
        def self.paginate(options = {})
          route_setting :per_page, options[:per_page]
          route_setting :max_per_page, options[:max_per_page]

          enforce_max_per_page = options[:max_per_page] && options[:enforce_max_per_page]
          per_page_values = enforce_max_per_page ? 0..options[:max_per_page] : nil

          params do
            optional :page,     :type   => Integer, :default => 1,
                                :desc   => 'Page of results to fetch.'
            optional :per_page, :type   => Integer, :default => options[:per_page],
                                :desc   => 'Number of results to return per page.',
                                :values => per_page_values
          end
        end
      end
    end

    class << self
      def paginate(collection, options = {})
        options[:page]     = options[:page].to_i
        options[:page]     = 1 if options[:page] <= 0
        options[:per_page] = options[:per_page].to_i

        case GrapeAPI.pagination.config.paginator
        when :pagy
          paginate_with_pagy(collection, options)
        when :kaminari
          paginate_with_kaminari(collection, options, options[:paginate_array_options] || {})
        when :will_paginate
          paginate_with_will_paginate(collection, options)
        else
          raise StandardError, "Unknown paginator: #{GrapeAPI.pagination.config.paginator}"
        end
      end

      def pages_from(collection, options = {})
        return pagy_pages_from(collection) if GrapeAPI.pagination.config.paginator == :pagy && collection.is_a?(Pagy)

        {}.tap do |pages|
          unless collection.first_page?
            pages[:first] = 1
            pages[:prev]  = collection.current_page - 1
          end

          unless collection.last_page? || (GrapeAPI.pagination.config.paginator == :kaminari && collection.out_of_range?)
            pages[:last] = collection.total_pages if GrapeAPI.pagination.config.include_total
            pages[:next] = collection.current_page + 1
          end
        end
      end

      def total_from(collection)
        case GrapeAPI.pagination.config.paginator
          when :pagy          then collection.count.to_s
          when :kaminari      then collection.total_count.to_s
          when :will_paginate then collection.total_entries.to_s
        end
      end

      private

      def paginate_with_pagy(collection, options)
        if Pagy::VARS[:max_per_page] && options[:per_page] > Pagy::VARS[:max_per_page]
          options[:per_page] = Pagy::VARS[:max_per_page]
        elsif options[:per_page] <= 0
          options[:per_page] = Pagy::VARS[:items]
        end

        pagy = pagy_from(collection, options)
        collection = if collection.respond_to?(:offset) && collection.respond_to?(:limit)
          collection.offset(pagy.offset).limit(pagy.items)
        else
          collection[pagy.offset, pagy.items]
        end

        return [collection, pagy]
      end

      def pagy_from(collection, options)
        if options[:count]
          count = options[:count]
        else
          count = collection.is_a?(Array) ? collection.count : collection.count(:all)
        end

        Pagy.new(count: count, items: options[:per_page], page: options[:page])
      end

      def pagy_pages_from(pagy)
        {}.tap do |pages|
          unless pagy.page == 1
            pages[:first] = 1
            pages[:prev]  = pagy.prev
          end

          unless pagy.page == pagy.pages
            pages[:last] = pagy.pages if GrapeAPI.pagination.config.include_total
            pages[:next] = pagy.next
          end
        end
      end

      def paginate_with_kaminari(collection, options, paginate_array_options = {})
        if Kaminari.config.max_per_page && options[:per_page] > Kaminari.config.max_per_page
          options[:per_page] = Kaminari.config.max_per_page
        elsif options[:per_page] <= 0
          options[:per_page] = get_default_per_page_for_kaminari(collection)
        end

        collection = Kaminari.paginate_array(collection, paginate_array_options) if collection.is_a?(Array)
        collection = collection.page(options[:page]).per(options[:per_page])
        collection.without_count if !collection.is_a?(Array) && !GrapeAPI.pagination.config.include_total
        [collection, nil]
      end

      def paginate_with_will_paginate(collection, options)
        if options[:per_page] <= 0
          options[:per_page] = default_per_page_for_will_paginate(collection)
        end

        collection = if defined?(Sequel::Dataset) && collection.kind_of?(Sequel::Dataset)
          collection.paginate(options[:page], options[:per_page])
        else
          supported_options = [:page, :per_page, :total_entries]
          options = options.dup.keep_if { |k,v| supported_options.include?(k.to_sym) }
          collection.paginate(options)
        end

        [collection, nil]
      end

      def get_default_per_page_for_kaminari(collection)
        default = Kaminari.config.default_per_page
        extract_per_page_from_model(collection, :default_per_page) || default
      end

      def default_per_page_for_will_paginate(collection)
        default = WillPaginate.per_page
        extract_per_page_from_model(collection, :per_page) || default
      end

      def extract_per_page_from_model(collection, accessor)
        klass = if collection.respond_to?(:klass)
          collection.klass
        else
          collection.first.class
        end

        return unless klass.respond_to?(accessor)
        klass.send(accessor)
      end
    end

  end
end
