class Admin::FileManagerController < AdminController
  include FileSystemHelper
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
      files = []
      file_counter = 0
      loop do
        file_param = params["file-#{file_counter}"]
        break if file_param.nil?
        files << file_param
        file_counter += 1
      end
      @result_message = {result: upload_files(params[:destination], files)}
      @result_status = 200
    else
      unknown_action(params[:action])
    end

    render :json => @result_message, :status => @result_status
  end

  def download
    preview = (params[:preview] == true)
    external_url = obtain_external_url(params[:path], preview)
    if preview
      redirect_to external_url
    else
      if is_local_filesystem
        send_file external_url
      else
        filename = File.basename(params[:path])
        file = open(external_url)
        content_type = file.content_type
        send_data file.read, :type => content_type, :filename => filename
      end
    end
  end

  private

  def list_action(params)
    @result_message = {result: list_files(params[:path], params[:onlyFolders])}
    @result_status = 200
  end

  def add_folder_action(params)
    @result_message = {result: add_folder(params[:path], params[:name])}
    @result_status = 200
  end

  def delete_action(params)
    @result_message = {result: delete(params[:path])}
    @result_status = 200
  end

  def rename_action(params)
    @result_message = {result: rename(params[:path], params[:newPath])}
    @result_status = 200
  end

  def copy_action(params)
    @result_message = {result: copy(params[:path], params[:newPath])}
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