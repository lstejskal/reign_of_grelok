# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "grelok/version"

Gem::Specification.new do |s|
  s.name        = "grelok"
  s.version     = Grelok::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Lukas Stejskal"]
  s.email       = ["lucastej@gmail.com"]
  s.homepage    = "http://github.com/lstejskal/reign_of_grelok"
  s.summary     = %q{Reign of Grelok - Ruby rewrite of mini-adventure game from Fallout 3}
  s.description = %q{Easter egg from Fallout 3, small adventure text game, rewritten in Ruby}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test}/*`.split("\n")
  s.require_paths = ["lib"]

  s.add_dependency('rake', '~> 10.0')

  # test dependencies 
  s.add_development_dependency('shoulda', '~> 3.4.0')
  s.add_development_dependency('turn', '~> 0.9.6')
  s.add_development_dependency('mocha', '~> 0.13.3')
end
