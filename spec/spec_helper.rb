$:.unshift File.expand_path("../lib", __FILE__)
$:.unshift File.expand_path("../spec", __FILE__)
Bundler.require(:default)

require 'poller'
require 'dropbox_poller'
require 'dropbox_message'

require 'fake_dropbox_client'
require 'fake_dropbox_session'

RSpec.configure do |config|
  # == Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  config.mock_with :rspec

  config.color_enabled = true
end