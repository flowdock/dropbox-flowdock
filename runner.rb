require 'bundler'
require File.expand_path('../environment', __FILE__)
require File.join(File.dirname(__FILE__), "environment.rb")

abort("Argument missing: please specify a class to run!") unless ARGV[0]

require ARGV[0]
runner = Object.const_get(ARGV[0].split(/_/).map(&:capitalize).join("")).new
runner.start!