class DropboxMessage

  attr_accessor :action, :type, :path, :data, :subject, :content, :link, :share_link, :files

  ACTIONS = {:add => "added", :update => "updated", :delete => "deleted"}

  def initialize(entry, action, previous_entry)
    @path, @data = entry
    @action = action
    @share_link = @data["link"] unless @data.nil?

    # in case of delete action @data is nil => must check the previous entry
    if (@data && @data["is_dir"]) || (previous_entry && previous_entry["is_dir"])
      @type = :folder
    else
      @type = :file
    end
  end

  def link
    "https://www.dropbox.com/home#{File.dirname(@path)}"
  end

  def as_team_inbox_message
    if @type == :folder
      folder_message
    elsif @type == :file
      file_message
    end
  end

  private

  def folder_message
    {
      :subject => "Folder #{File.basename(path)} #{ACTIONS[@action]}",
      :content => "Folder <a href=\"https://www.dropbox.com/home#{path}\">#{File.basename(@path)}</a> was #{ACTIONS[@action]}.",
      :link => link
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
      :content => "File #{file_link} was #{full_action} Dropbox folder <a href=\"https://www.dropbox.com/home#{File.dirname(@path)}\">#{folder}</a>.",
      :link => link
    }
  end
end