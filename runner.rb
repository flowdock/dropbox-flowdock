require 'bundler'
require File.expand_path('../environment', __FILE__)
require File.join(File.dirname(__FILE__), "environment.rb")

$stdout.sync = true

abort("Argument missing: please specify a class to run!") unless ARGV[0]

runner = Object.const_get(ARGV[0]).new
runner.start!