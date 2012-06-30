# -*- encoding: utf-8 -*-
require File.expand_path('../lib/motion-state-machine/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Sebastian Burkhart"]
  gem.email         = ["sebastianburkhart@me.com"]
  gem.description   = %q{A finite state machine for RubyMotion with a flavor of Grand Central Dispatch.}
  gem.summary       = %q{Comes with a nice syntax for state and transition definition. Supports triggering via events, timeouts and NSNotifications.}
  gem.homepage      = "https://github.com/opyh/motion-state-machine"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "motion-state-machine"
  gem.require_paths = ["lib"]
  gem.version       = StateMachine::VERSION

  gem.add_development_dependency 'rake'
end
