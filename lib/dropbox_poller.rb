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
      @reading_reset = false
      return true
    end

    @messages = {}
    delta["entries"].each do |entry|
      path, data = entry
      action = parse_action(entry)
      previous_entry = @folder_state[path]

      update_folder_state(entry)
      msg = DropboxMessage.new(entry, action, previous_entry)
      msg.share_link = share_link(path)
      @messages.merge!({path => msg})
    end

    @root_paths = []
    notifications = @messages.map do |path, msg|
      if @root_paths.empty? || @root_paths.reject! { |root_path| root_path.match(/^#{path}/) }
        @root_paths << path
      end
    end

    @root_paths.each { |root_path| push_to_flows(@messages[root_path]) }

    true
  end

  def polling_interval
    60
  end

  private

  def parse_action(entry)
    path, data = entry
    if data == nil
      return :delete
    else
      if @folder_state[path] == nil
        return :add
      else
        return :update
      end
    end
  end

  def share_link(path)
    if !File.directory?(path)
      # get share link for the file
      @client.shares(path)["url"]
    end
  end

  def update_folder_state(entry)
    path, data = entry
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