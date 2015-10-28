class Admin::FileManagerController < AdminController
  include FileSystemHelper
  layout false
  skip_before_action :verify_authenticity_token

  def handler
    case params[:params][:mode]
      when "list" then
        list_action(params[:params])
      when "addfolder" then
        add_folder_action(params[:params])
      when "delete" then
        delete_action(params[:params])
      when "rename" then
        rename_action(params[:params])
      when "copy" then
        copy_action(params[:params])
      else
        unknown_action(params[:params])
    end

    render :json => @result_message, :status => @result_status
  end

  def upload
    if params[:action] == 'upload'
      # final_destination = params[:pwd].nil? ? params[:destination] : params[:pwd] + params[:destination]
      files = []
      file_counter = 0
      loop do
        file_param = params["file-#{file_counter}"]
        break if file_param.nil?
        files << file_param
        file_counter += 1
      end
      @result_message = {result: upload_files(params[:destination], params[:pwd], files)}
      @result_status = 200
    else
      unknown_action(params[:action])
    end

    render :json => @result_message, :status => @result_status
  end

  def download
    preview = (params[:preview] == 'true')
    external_url = obtain_external_url(params[:path], nil, preview)
    if preview
      redirect_to external_url
    else
      # if is_local_filesystem
      #   send_file external_url
      # else
      filename = File.basename(params[:path])
      file = open(external_url)
      content_type = file.content_type
      send_data file.read, :type => content_type, :filename => filename
      # end
    end
  end

  def templates
    render "admin/file_manager/#{params[:view]}"
  end

  def view
    if params[:config].nil?
      render :config_default, :layout => false
    else
      render "config_#{params[:config]}", :layout => false
    end
  end

  private

  def list_action(params)
    @result_message = {result: list_files(params[:path], params[:pwd], params[:onlyFolders], params[:mimeFilter])}
    @result_status = 200
  end

  def add_folder_action(params)
    @result_message = {result: add_folder(params[:path], params[:pwd], params[:name])}
    @result_status = 200
  end

  def delete_action(params)
    isDirectory = params[:type].nil? ? false : params[:type].eql?('dir')
    @result_message = {result: delete(params[:path], params[:pwd], isDirectory)}
    @result_status = 200
  end

  def rename_action(params)
    @result_message = {result: rename(params[:path], params[:pwd], params[:newPath])}
    @result_status = 200
  end

  def copy_action(params)
    @result_message = {result: copy(params[:path], params[:pwd], params[:newPath])}
    @result_status = 200
  end

  def unknown_action(params)
    @result_status = 405
    @result_message = "Method not allowed"
  end

  def file_permissions(file)
    "drwxr-xr-x"
  end
end