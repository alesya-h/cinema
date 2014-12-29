# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cinema/version'

Gem::Specification.new do |spec|
  spec.name          = "cinema"
  spec.version       = Cinema::VERSION
  spec.authors       = ["Ales Guzik"]
  spec.email         = ["me@aguzik.net"]
  spec.summary       = %q{Select movie from trakt.tv watchlist and stream it from torrents}
  spec.description   = %q{}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_dependency "traktr", ">=0.7.0"
  spec.add_dependency "yify", ">=0.0.1"
end
