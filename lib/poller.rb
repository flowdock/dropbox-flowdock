require 'flowdock'

class Poller
  def initialize
    @flows = []
    ENV["FLOW_TOKENS"].split(/,/).each do |api_token|
      @flows << Flowdock::Flow.new(:api_token => api_token,
        :source => ENV["SOURCE"], :from => { :name => ENV["FROM_NAME"], :address => ENV["FROM_ADDRESS"] })
    end
  end

  def run
    raise NotImplementedError, "You must override this method in your subclass!"
  end

  def polling_interval
    raise NotImplementedError, "You must override this method in your subclass!"
  end

  def start!
    while(run)
      sleep(polling_interval)
    end
  end
end