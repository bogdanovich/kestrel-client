# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kestrel/client/version'

Gem::Specification.new do |s|
  s.name = "kestrel-client"
  s.version = Kestrel::VERSION

  s.authors = ["Matt Freels", "Rael Dornfest", "Anton Bogdanovich"]
  s.summary = "Ruby Kestrel client"
  s.description = "Ruby client for the Kestrel queue server"
  s.email = "anton@bogdanovich.co"
  s.license = "Apache-2"
  s.extra_rdoc_files = [
    "README.md"
  ]
  s.files = `git ls-files -z`.split("\x0")
  s.homepage = "http://github.com/bogdanovich/siberite-ruby"

  s.add_dependency(%q<memcached>, [">= 0.19.6"])

  s.files         = `git ls-files -z`.split("\x0")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_development_dependency "pry", "~> 0.10"
  s.add_development_dependency "pry-byebug", "~> 2.0"
  s.add_development_dependency "rspec", "~> 3.2"
  s.add_development_dependency "rr", "~> 1.1"
  s.add_development_dependency "activesupport", "> 3.1"
  s.add_development_dependency "bundler", "~> 1.7"
  s.add_development_dependency "rake", "~> 10.0"
end
