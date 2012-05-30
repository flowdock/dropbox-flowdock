require 'multi_json'

class FakeDropboxClient

  def account_info(*args)
    return MultiJson.decode(File.read(File.new("/Users/tide/Documents/flowdock-dropbox/spec/fixtures/account_info.json")))
  end

  def delta(cursor)
    @i ||= 0
    @i += 1
    puts "Serving delta#{@i}.json"
    return MultiJson.decode(File.read(File.new("/Users/tide/Documents/flowdock-dropbox/spec/fixtures/deltas/delta#{@i}.json")))
  end

  def shares(*args)
    {:url => "http://www.example.com", :expires => "Tue, 01 Jan 2030 00:00:00 +0000"}
  end
end