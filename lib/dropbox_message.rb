class DropboxMessage

  attr_accessor :action, :type, :path, :data, :subject, :content, :link, :share_link, :files

  ACTIONS = {:add => "added", :update => "updated", :delete => "deleted"}

  def initialize(entry, action, previous_entry)
    @path, @data = entry
    @action = action

    # in case of delete action @data is nil => must check the previous entry
    if (@data && @data["is_dir"]) || (previous_entry && previous_entry["is_dir"])
      @type = :folder
    else
      @type = :file
    end
  end

  def link(path)
    "https://www.dropbox.com/home#{path}"
  end

  def as_team_inbox_message
    case @type
      when :folder then folder_message
      when :file then file_message
      else raise "Unknown Dropbox message type: path: #{@path} | data: #{@data.inspect}"
    end
  end

  private

  def folder_message
    if @action == :add || @action == :update
      folder_link = link(@path)
      folder_name = "<a href=\"#{folder_link}\">#{File.basename(@path)}</a>"
    elsif @action == :delete
      folder_link = nil
      folder_name = File.basename(@path)
    end

    {
      :subject => "Folder #{File.basename(path)} #{ACTIONS[@action]}",
      :content => "Folder #{folder_name} was #{ACTIONS[@action]}.",
      :link => folder_link
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
      :subject => "File #{File.basename(@path)} #{ACTIONS[@action]}",
      :content => "File #{file_link} was #{full_action} <a href=\"https://www.dropbox.com/home#{File.dirname(@path)}\">#{folder}</a>.",
      :link => link(File.dirname(@path))
    }
  end
end