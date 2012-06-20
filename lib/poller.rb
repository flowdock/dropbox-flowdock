require 'flowdock'

class Poller
  attr_reader :flows

  def initialize
    raise "Environment variable FLOW_TOKENS is not defined!" unless ENV["FLOW_TOKENS"]
    @flows = []
    ENV["FLOW_TOKENS"].split(/,/).map(&:strip).each do |api_token|
      @flows << Flowdock::Flow.new(:api_token => api_token,
        :source => ENV["SOURCE"], :from => { :name => ENV["FROM_NAME"], :address => ENV["FROM_ADDRESS"] })
    end
  end

  def run!
    raise NotImplementedError, "You must override this method in your subclass!"
  end

  def polling_interval
    raise NotImplementedError, "You must override this method in your subclass!"
  end

  def start!
    puts "Started poller #{self.class}"
    while(run!)
      sleep(polling_interval)
    end
  end
end