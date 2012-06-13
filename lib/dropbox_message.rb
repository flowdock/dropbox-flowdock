class DropboxMessage

  attr_accessor :action, :type, :path, :data, :share_link

  ACTIONS = { add: "added", update: "updated", delete: "deleted" }

  def initialize(entry, action, prev_data)
    @path, @data = entry
    @action = action

    # in case of delete action @data is nil => must check the previous entry
    if (@data && @data["is_dir"]) || (prev_data && prev_data["is_dir"])
      @type = :folder
    else
      @type = :file
    end
  end

  def as_team_inbox_message
    case @type
      when :folder then folder_message
      when :file then file_message
      else raise "Unknown Dropbox message type: path: #{@path} | data: #{@data.inspect}"
    end
  end

  def self.path_link(path)
    "https://www.dropbox.com/home#{path}"
  end

  def self.aggregate(path, msgs)
    stats = { add: 0, update: 0, delete: 0 }
    files_list = { add: [], update: [], delete: []}
    msgs.each do |msg|
      stats[msg.action] += 1

      if msg.action == :delete
        files_list[msg.action] << " #{File.basename(msg.path)}"
      else
        files_list[msg.action] << " <a href=\"#{msg.share_link}\">#{File.basename(msg.path)}</a>"
      end
    end

    activity = stats.map { |k,v| "#{v} file#{'s' if v > 1} #{ACTIONS[k]}" if v > 0 }.compact.join(", ")
    content = files_list.map { |k,v| "#{ACTIONS[k].capitalize}:\n" + v.join("\n") if v.size > 0 }.compact.join("\n\n")

    {
      subject: "Activity in #{File.basename(path)}: #{activity}",
      content: content,
      link: path_link(path)
    }
  end

  private

  def folder_message
    if @action == :add || @action == :update
      folder_link = self.class.path_link(@path)
      folder_name = "<a href=\"#{folder_link}\">#{File.basename(@path)}</a>"
    elsif @action == :delete
      folder_link = nil
      folder_name = File.basename(@path)
    end

    {
      subject: "Folder #{File.basename(path)} #{ACTIONS[@action]}",
      content: "Folder #{folder_name} was #{ACTIONS[@action]}.",
      link: folder_link
    }
  end

  def file_message
    full_action = case @action
      when :add then "added to"
      when :update then "updated in"
      when :delete then  "deleted from"
    end

    folder = File.dirname(@path)
    folder = 'Home' if folder == '/'

    file_link = if @action == :delete
      File.basename(@path)
    else
      "<a href=\"#{@share_link}\">#{File.basename(@path)}</a>"
    end

    {
      subject: "File #{File.basename(@path)} #{ACTIONS[@action]}",
      content: "File #{file_link} was #{full_action} <a href=\"https://www.dropbox.com/home#{File.dirname(@path)}\">#{folder}</a>.",
      link: self.class.path_link(File.dirname(@path))
    }
  end
end