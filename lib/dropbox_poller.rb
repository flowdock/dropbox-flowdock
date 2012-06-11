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
      delta = @client.delta(@cursor)
      @cursor = delta["cursor"]

      @folder_state.merge!(parse_folder_state(delta["entries"]))
    end

    if @reading_reset
      # after reading initial state, wait for real deltas
      puts "Received initial delta with #{@folder_state.size} entries"
      @reading_reset = false
      return true
    end

    puts "Received delta with #{delta["entries"].size} entries"

    # parse entries in delta
    @messages = {}
    delta["entries"].each do |entry|
      path, data = entry
      action = parse_action(entry)
      prev_entry = @folder_state[path]

      # update folder state and store entry
      update_folder_state(entry, action)
      @messages.merge!({path => {:entry => entry, :prev_entry => prev_entry, :action => action}})
    end

    # figure out the shortest paths in the received delta entries
    # eg. case "/test/foo/bar.png": deleted, "/test": deleted
    # => in order to reduce noise, we should only notify about the deletion of the root folder
    @root_paths = []
    notifications = @messages.map do |path, msg|
      is_parent = @root_paths.reject! { |root_path| root_path.match(/^#{path}/) } # check if path is parent of some root_paths
      subpaths = @root_paths.select { |root_path| path.match(/^#{root_path}/) } # check if root_paths already contains some parent of given path
      if @root_paths.empty? || !is_parent.nil? || subpaths.empty?
        @root_paths << path
      end
    end

    # send notification of each root path entry
    @root_paths.each do |root_path|
      entry_hash = @messages[root_path]
      msg = DropboxMessage.new(entry_hash[:entry], entry_hash[:action], entry_hash[:prev_entry])
      msg.share_link = share_link(root_path) unless entry_hash[:action] == :delete
      push_to_flows(msg)
    end

    true
  end

  def polling_interval
    300 # Dropbox API encourages to have at least 5 minutes between polling
  end

  private

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

  def update_folder_state(entry, action)
    path, data = entry
    case action
      when :delete then @folder_state.delete(path)
      when :add then @folder_state[path] = data
      when :update then @folder_state[path].merge!(data)
    end
  end

  def push_to_flows(dropbox_msg)
    puts "Pushing notification to #{@flows.size} flows"
    @flows.each do |flow|
      begin
        flow.push_to_team_inbox({:tags => ["dropbox"]}.merge(dropbox_msg.as_team_inbox_message))
      rescue => e
        puts "Unable to nofity flow: #{flow.inspect}"
        puts e.to_s
      end
    end
  end

  def parse_folder_state(entries)
    entries.reduce({}) { |entries, entry|
      entries.merge({ entry[0] => entry[1] })
    }
  end
end