require 'multi_json'

class FakeDropboxClient

  def account_info(*args)
    return MultiJson.decode(File.read(File.new(File.join("spec", "fixtures", "account_info.json"))))
  end

  def delta(cursor)
    @i ||= 0
    @i += 1

    num = if @i < 10 then "0#{@i}" else @i.to_s end
    delta_json_path = File.join("spec", "fixtures", "deltas", "delta#{num}.json")
    if File.exists?(delta_json_path)
      return MultiJson.decode(File.read(File.new(delta_json_path)))
    else
      return {"entries" => []}
    end
  end

  def shares(*args)
    {"url" => "https://www.dropbox.com/s/q6p2bn9td2wjwfb", "expires" => "Tue, 01 Jan 2030 00:00:00 +0000"}
  end
end