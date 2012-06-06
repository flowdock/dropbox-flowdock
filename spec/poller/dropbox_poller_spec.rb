require 'spec_helper'

ENV["FLOW_TOKENS"] = "deadbeefdeadbeef,3ee7818aab66ee16f5d30cfd96e0100c"
ENV["SOURCE"] = "dropbox"
ENV["FROM_ADDRESS"] = "foo@example.com"
ENV["FROM_NAME"] = "Dropbox"

describe DropboxPoller do
  describe "when running for the first time" do
    it "initializes Dropbox session and client" do
      DropboxSession.should_receive(:new).and_return(FakeDropboxSession.new)
      DropboxClient.should_receive(:new).and_return(FakeDropboxClient.new)
      @poller = DropboxPoller.new
      @poller.run!.should eq(true)
    end
  end

  describe "when listening for deltas" do
    before :all do
      @poller = DropboxPoller.new
      @poller.stub(:polling_interval).and_return(5)
      @poller.session = FakeDropboxSession.new
      @poller.client = FakeDropboxClient.new
      @poller.should_not_receive(:init_session)
    end

    it "parses initial state (delta1 & delta2)" do
      @poller.run!
      @poller.folder_state.should_not be_empty
      @poller.folder_state["/test/index.html"].should_not be_nil
    end

    it "parses adding a folder with files and aggregates it into one notification (delta3)" do
      should_send_notification({:tags => ["dropbox"], :subject => "Folder testing added",
        :content=>"Folder <a href=\"https://www.dropbox.com/home/testing\">testing</a> was added.",
        :link=>"https://www.dropbox.com/home/testing"})
      @poller.run!
    end

    it "parses adding a file (delta4)" do
      should_send_notification({:tags => ["dropbox"], :subject => "File influx_bug.png added",
        :content=>"File <a href=\"https://www.dropbox.com/s/q6p2bn9td2wjwfb\">influx_bug.png</a> was added to <a href=\"https://www.dropbox.com/home/\">Home</a>.",
        :link=>"https://www.dropbox.com/home/"})
      @poller.run!
    end

    it "parses deleting a file (delta5)" do
      should_send_notification({:tags => ["dropbox"], :subject => "File influx_bug.png deleted",
        :content=>"File influx_bug.png was deleted from <a href=\"https://www.dropbox.com/home/\">Home</a>.",
        :link=>"https://www.dropbox.com/home/"})
      @poller.run!
    end

    it "parses deleting folder with files and aggregates it into one notification (delta6)" do
      should_send_notification({:tags => ["dropbox"], :subject => "Folder testing deleted",
        :content=>"Folder testing was deleted.",
        :link=> nil})
      @poller.run!
    end

    it "parses updating a file (delta7)" do
      should_send_notification({:tags => ["dropbox"], :subject => "File index.html updated",
        :content=>"File <a href=\"https://www.dropbox.com/s/q6p2bn9td2wjwfb\">index.html</a> was updated in <a href=\"https://www.dropbox.com/home/test\">/test</a>.",
        :link=>"https://www.dropbox.com/home/test"})
      @poller.run!
    end

  end

  def should_send_notification(params)
    @poller.flows.each { |flow| flow.should_receive(:push_to_team_inbox).with(params).once }
  end
end