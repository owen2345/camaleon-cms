require 'will_paginate/array'
class CamaleonCms::Admin::MediaController < CamaleonCms::AdminController
  skip_before_action :admin_logged_actions, except: [:index, :download_private_file], raise: false
  skip_before_action :verify_authenticity_token, only: :upload, raise: false
  before_action :init_media_vars, except: :download_private_file

  # render media section
  def index
    authorize! :manage, :media

    load_explorer('/')

    add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.media")
  end

  # crop a image to save as a new file
  def crop
    path_image = cama_tmp_upload(params[:cp_img_path])[:file_path]
    crop_path = cama_crop_image(path_image, params[:ic_w], params[:ic_h], params[:ic_x], params[:ic_y])
    res = upload_file(crop_path, {remove_source: true})
    CamaleonCms::User.find(params[:saved_avatar]).set_meta('avatar', res["url"]) if params[:saved_avatar].present? # save current crop image as avatar
    render html: res["url"].html_safe
  end

  # download private files
  def download_private_file
    f_path = CamaleonCmsLocalUploader::private_file_path(params[:file], current_site)
    if File.exist?(f_path)
      send_file f_path, disposition: 'inline'
    else
      raise ActionController::RoutingError, 'File not found'
    end
  end

  # render media for modal content
  def ajax
    folder_path = params[:folder].blank? ? '/' : params[:folder]

    load_explorer(folder_path, params[:search])

    if params[:partial].present?
      render json: { next_page: @next_page, html: render_to_string(partial: 'files_list', locals: { files: @files, folders: @folders })}
    else
      render 'index', layout: false
    end
  end

  # do background actions in fog
  def actions
    authorize! :manage, :media if params[:media_action] != 'crop_url'

    params[:folder] = params[:folder].gsub('//', '/') if params[:folder].present?

    case params[:media_action]
      when 'new_folder'
        params[:folder] = CamaleonCmsUploader.slugify_folder(params[:folder])
        render partial: 'render_folder_item', 
          locals: { folders: [cama_uploader.add_folder(params[:folder])] }

      when 'del_folder'
        cama_uploader.delete_folder(params[:folder])
        render inline: ''

      when 'del_file'
        cama_uploader.delete_file(params[:folder].gsub('//', '/'))
        render inline: ''

      when 'crop_url'
        params[:url] = (params[:url].start_with?('http') ? '' : current_site.the_url(locale: nil)) + params[:url]
        r = cama_tmp_upload(params[:url], formats: params[:formats], name: params[:name])

        if r[:error].blank?
          params[:file_upload] = r[:file_path]
          sett = { remove_source: true }
          sett[:same_name] = true if params[:same_name].present?
          sett[:name] = params[:name] if params[:name].present?
          upload(sett)
        else
          render inline: r[:error]
        end
    end
  end

  # upload files from media uploader
  def upload(settings = {})
    params[:dimension] = nil if params[:skip_auto_crop].present?
    f = { error: "File not found." }

    if params[:file_upload].present?
      f = upload_file(
        params[:file_upload], { 
          folder: params[:folder], 
          dimension: params['dimension'], 
          formats: params[:formats], 
          versions: params[:versions], 
          thumb_size: params[:thumb_size] 
        }.merge(settings))
    end

    if f[:error].present?
      render inline: f[:error]
    else
      render(partial: 'render_file_item', locals: { files: [f] })
    end
  end

  def load_explorer(folder, search = '')
    @show_file_actions = true
    @folders = []

    # paging not implemented
    # .paginate(page: page, per_page: 100)

    @files = CamaleonCms::Media.where(is_folder: false).search(search, folder)

    # search only targets files so
    return if search.present?

    @folders = CamaleonCms::Media.where(folder_path: folder, is_folder: true)
  end

  private

  # init basic media variables
  def init_media_vars
    @cama_uploader = CamaleonCmsLocalUploader.new({current_site: current_site, private: true}) if params[:private].present?
    @media_formats = (params[:media_formats] || "").sub("media", ",video,audio").sub("all", "").split(",")
    @show_file_actions ||= params[:actions].to_s == 'true'
  end
end
