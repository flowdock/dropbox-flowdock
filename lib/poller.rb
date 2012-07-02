require 'flowdock'

class Poller
  attr_reader :flows

  def initialize
    ["FLOW_TOKENS", "SOURCE", "FROM_NAME", "FROM_ADDRESS"].each { |var| raise "Environment variable #{var} is not defined!" unless ENV[var] }
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