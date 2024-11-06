require_relative 'lib/pubchem_api/version'

Gem::Specification.new do |spec|
  spec.name          = "pubchem_api"
  spec.version       = PubChemAPI::VERSION
  spec.summary       = "PubChem PUG REST api wrapper"
  spec.description   = "PubChem PUG REST api wrapper module"
  spec.authors       = ["coderobe"]
  spec.email         = ["git@coderobe.net"]
  spec.homepage      = "https://github.com/coderobe/ruby-pubchem_api"
  spec.licenses      = ["MIT"]

  spec.files         = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]

  spec.add_dependency "httparty", "~> 0.22.0"
  spec.add_dependency "nokogiri", "~> 1.16.7"
end
