require 'dropbox_sdk'
require 'multi_json'

class DropboxPoller < Poller

  APP_KEY = 'ai3selxkgpj7hvm'
  APP_SECRET = 'lghetp1d3m3bquq'

  USER_TOKEN = 'ebodiaxjk8scvar'
  USER_SECRET = '1ypaoel3zqzxdcr'

  def init_session
    @session = DropboxSession.new(APP_KEY, APP_SECRET)
    @session.set_access_token(USER_TOKEN, USER_SECRET)

    @client = FakeDropboxClient.new #DropboxClient.new(@session, :dropbox)
    puts "linked account:", @client.account_info().inspect
  end

  def run
    init_session if @session.nil?
    puts "run"

    delta = @client.delta(@cursor)
    @cursor = delta["cursor"]

    # keep initial state for detecting updates to existing files
    # (no indication provided by the delta API, just "added" or "deleted")
    if delta["reset"]
      @reading_reset = true
      @folder_state = parse_folder_state(delta["entries"])
    end

    # keep reading if delta comes in as multiple chunks
    while(delta["has_more"])
      puts "has_more"
      delta = @client.delta(@cursor)
      @cursor = delta["cursor"]

      @folder_state.merge!(parse_folder_state(delta["entries"]))
    end

    if @reading_reset
      # after reading initial state, wait for real deltas
      @reading_reset = false
      return true
    end

    @messages = {}
    delta["entries"].each do |entry|
      path, data = entry
      previous_entry = @folder_state[path]
      update_folder_state(entry)
      msg = DropboxMessage.new(entry, parse_action(entry), previous_entry)
      @messages.merge!({path => msg})
    end

    puts @messages.inspect

    @root_paths = []
    notifications = @messages.map do |path, msg|
      if @root_paths.empty? || @root_paths.reject! { |root_path| root_path.match(/^#{path}/) }
        @root_paths << path
      end
    end

    puts @root_paths.inspect

    @root_paths.each { |root_path| push_to_flows(@messages[root_path]) }

    puts "Finished run, sleeping 60 secs"
    true
  end

  def polling_interval
    5
  end

  private

  def look_up(folders, path)
    path_parts = path.split(File::PATH_SEPARATOR)
    path_parts.delete(path_parts.last)
    parent = File.join(path_parts)
    if folders[parent] != nil
      look_up(folders, parent)
    else
      path
    end
  end

  def parse_action(entry)
    path, data = entry
    if data == nil
      return :delete
    else
      if @folder_state[path] == nil
        return :add
      else
        puts "data of #{path}: #{@folder_state[path].inspect}"
        return :update
      end
    end
  end

  def update_folder_state(entry)
    path, data = entry
    is_dir = File.directory?(path)
    action = parse_action(entry)
    if action == :delete
      @folder_state.delete(path)
    else
      # keep up the state
      if action == :add
        @folder_state.merge!({path => data})
      elsif action == :update
        @folder_state[path].merge!(data)
      end

      if !is_dir && !@folder_state[path]["link"]
        # get new share link for the file
        link_data = @client.shares(path)
        puts "Link to #{path} expires #{link_data["expires"]}"
        # store for later usage
        @folder_state[path]["link"] = link_data["url"]
      end
    end
  end

  def push_to_flows(dropbox_msg)
    @flows.each { |flow| flow.push_to_team_inbox({:tags => ["dropbox"]}.merge(dropbox_msg.as_team_inbox_message)) }
  end

  def parse_folder_state(entries)
    entries.reduce({}) { |entries, entry|
      entries.merge({ entry[0] => entry[1] })
    }
  end
end