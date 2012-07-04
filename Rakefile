require 'bundler'
require File.expand_path('../environment', __FILE__)
require File.join(File.dirname(__FILE__), "environment.rb")
$stdout.sync = true

require "dropbox-api/tasks"
Dropbox::API::Tasks.install

namespace :pollers do
  namespace :dropbox do
    task :start do |t, args|
      DropboxPoller.new.start!
    end
  end
end
