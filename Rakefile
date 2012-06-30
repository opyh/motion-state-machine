#!/usr/bin/env rake

$:.unshift("/Library/RubyMotion/lib")

require 'rubygems'
require 'rake'
require 'motion/project'
require "bundler/gem_tasks"

Bundler.setup
Bundler.require

Motion::Project::App.setup do |app|
  app.name = 'testSuite'
  app.identifier = 'com.screenfashion.motion-state-machine.spec-app'
  app.specs_dir = './spec/motion-state-machine'
  app.development do
    # TODO: How to use module namespacing here?
    app.delegate_class = 'MotionStateMachineSpecAppDelegate'
  end
end

# namespace :spec do
#   task :lib do
#     sh "bacon #{Dir.glob("spec/lib/**/*_spec.rb").join(' ')}"
#   end
# 
#   task :motion => 'spec'
# 
#   task :all => [:lib, :motion]
# end
