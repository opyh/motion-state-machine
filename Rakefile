#!/usr/bin/env rake

$:.unshift("/Library/RubyMotion/lib")

require 'rubygems'
require 'rake'
require 'motion/project'
require "bundler/gem_tasks"

Bundler.setup
Bundler.require

Motion::Project::App.setup do |app|
  app.name = 'Spec Suite'
  app.identifier = 'com.screenfashion.motion.spec-app'
  app.specs_dir = './spec'
  app.development do
    # TODO: How to use module namespacing here?
    app.delegate_class = 'SpecAppDelegate'
  end
end
