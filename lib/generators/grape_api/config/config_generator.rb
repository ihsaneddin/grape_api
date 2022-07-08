module GrapeAPI
  module Generators
    class ConfigGenerator < Rails::Generators::Base
      source_root File.join(__dir__, "templates")

      def generate_config
        copy_file "grape_api.rb", "config/initializers/grape_api.rb"
      end
    end
  end
end