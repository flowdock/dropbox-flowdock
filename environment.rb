$:.unshift File.expand_path("../lib", __FILE__)
$:.unshift File.expand_path("../spec", __FILE__)
Bundler.require(:default)

require 'poller'
require 'dropbox_poller'
require 'dropbox_message'

require 'fake_dropbox_client'
