require 'dropbox_sdk'
require 'multi_json'

class DropboxPoller < Poller

  attr_accessor :session, :client, :folder_state

  def init_session
    ["APP_KEY", "APP_SECRET", "USER_TOKEN", "USER_SECRET"].each { |var| raise "Environment variable #{var} is not defined!" unless ENV[var] }
    @session = DropboxSession.new(ENV["APP_KEY"], ENV["APP_SECRET"])
    @session.set_access_token(ENV["USER_TOKEN"], ENV["USER_SECRET"])

    @client = DropboxClient.new(@session, :dropbox)
  end

  def run!
    init_session if @session.nil?
    delta_entries = read_delta
    return true unless delta_entries # no entries => initial state read

    # parse entries in delta & update folder state
    parsed_entries = parse_delta_entries(delta_entries)
    update_folder_state(parsed_entries)

    # figure out the shortest paths in the received delta entries
    # eg. case "/test/foo/bar.png": deleted, "/test": deleted
    # => in order to reduce noise, we should only notify about the deletion of the parent folder
    shortest_paths = []
    notifications = parsed_entries.map do |path, entry_hash|
      is_parent = shortest_paths.reject! { |shortest_path| shortest_path.match(/^#{path}/) } # if path is parent of some item in shortest_paths => remove item
      subpaths = shortest_paths.select { |shortest_path| path.match(/^#{shortest_path}/) } # check if shortest_paths already contains some parent of given path

      # add this path to shortest paths if:
      # 1) there's no shortest paths yet
      # 2) path replaces one or more subfolders (removed already from shortest_paths)
      # 3) path isn't subfolder of any existing shortest_path (new path)
      if shortest_paths.empty? || !is_parent.nil? || subpaths.empty?
        shortest_paths << path
      end
    end

    # send notification of each shortest path entry
    @folders = []
    @files = {}
    shortest_paths.each do |shortest_path|
      entry_hash = parsed_entries[shortest_path]
      msg = DropboxMessage.new(entry_hash[:entry], entry_hash[:action], entry_hash[:prev_data])
      msg.share_link = share_link(shortest_path) unless entry_hash[:action] == :delete
      if msg.type == :folder
        @folders << msg
      else
        dirname = File.dirname(msg.path)
        @files[dirname] ||= []
        @files[dirname] << msg
      end
    end

    @folders.each { |msg| push_to_flows(msg.as_team_inbox_message) }
    @files.each { |path, msgs|
      if msgs.size > 1
        push_to_flows(DropboxMessage.aggregate(path, msgs))
      else
        push_to_flows(msgs.first.as_team_inbox_message)
      end
    }

    true
  end

  def polling_interval
    300 # Dropbox API encourages to have at least 5 minutes between polling
  end

  private

  def read_delta
    delta = @client.delta(@cursor)
    # cursor is used to define our last received delta point
    @cursor = delta["cursor"]

    # if reset is true => delta contains the initial state of the folder
    # let's keep the initial state for detecting updates to existing files
    @folder_state ||= {}
    reading_reset = false
    if delta["reset"]
      reading_reset = true
      @folder_state = parse_delta_entries(delta["entries"])
    end

    # keep reading if delta comes in as multiple chunks, the next delta can be fetched immediately according to API docs
    delta_entries = delta["entries"]
    while(delta["has_more"])
      delta = @client.delta(@cursor)
      @cursor = delta["cursor"]

      # push entries straight to folder state if reading initial state, otherwise collect them into new array
      if reading_reset
        @folder_state.merge!(parse_delta_entries(delta["entries"]))
      else
        delta_entries += delta["entries"]
      end
    end

    # after reading initial state, wait for real deltas
    return nil if reading_reset
    delta_entries
  end

  def parse_action(entry)
    path, data = entry
    if data == nil
      :delete
    elsif @folder_state[path] == nil
      :add
    else
      :update
    end
  end

  def share_link(path)
    if @folder_state[path] && !@folder_state[path]["is_dir"]
      # get share link for the file
      @client.shares(path)["url"]
    end
  end

  def update_folder_state(entries)
    entries.each do |path, entry_hash|
      path, data = entry_hash[:entry]
      case entry_hash[:action]
        when :delete then @folder_state.delete(path)
        when :add then @folder_state[path] = data
        when :update then @folder_state[path].merge!(data)
      end
    end
  end

  def push_to_flows(notification_options)
    puts "Pushing notification to #{@flows.size} flows"
    @flows.each do |flow|
      begin
        flow.push_to_team_inbox({:tags => ["dropbox"]}.merge(notification_options))
      rescue => e
        puts "Unable to nofity flow: #{flow.inspect}"
        puts e.to_s
      end
    end
  end

  def parse_delta_entries(delta_entries)
    delta_entries.reduce({}) { |entries, entry|
      path, data = entry
      action = parse_action(entry)
      entries.merge({ path => {:entry => entry, :prev_data => @folder_state[path], :action => action} })
    }
  end
end