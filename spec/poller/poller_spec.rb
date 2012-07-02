require 'spec_helper'

describe Poller do
  describe "when initialized" do
    before :each do
      ENV["FLOW_TOKENS"] = "deadbeefdeadbeef, 3ee7818aab66ee16f5d30cfd96e0100c "
      ENV["SOURCE"] = "dropbox"
      ENV["FROM_ADDRESS"] = "foo@example.com"
      ENV["FROM_NAME"] = "Dropbox"
      ENV["DROPBOX_PATH"] = "/"

      @poller = Poller.new
    end

    it "has API connection for each flow" do
      @poller.flows.size.should eq(2)
    end
  end
end