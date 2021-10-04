require_relative "lib/grape_api/version"

Gem::Specification.new do |spec|
  spec.name        = "grape_api"
  spec.version     = GrapeAPI::VERSION
  spec.authors     = [""]
  spec.email       = ["ihsaneddin@gmail.com"]
  spec.homepage    = "https://github.com/ihsaneddin"
  spec.summary     = "Summary of GrapeAPI."
  spec.description = "Description of GrapeAPI."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", "~> 6.1.3"
  spec.add_dependency "grape"
  spec.add_dependency "grape_on_rails_routes", "~> 0.3.2"
  spec.add_dependency "grape-entity", "~> 0.8.0"

end
