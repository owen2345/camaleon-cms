=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::Admin::MediaController < CamaleonCms::AdminController
  skip_before_action :admin_logged_actions, except: [:index, :download_private_file], raise: false
  skip_before_action :verify_authenticity_token, only: :upload, raise: false
  before_action :init_media_vars, except: :download_private_file

  # render media section
  def index
    authorize! :manage, :media
    @show_file_actions = true
    add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.media")
  end

  # crop a image to save as a new file
  def crop
    path_image = cama_tmp_upload(params[:cp_img_path])[:file_path]
    crop_path = cama_crop_image(path_image, params[:ic_w], params[:ic_h], params[:ic_x], params[:ic_y])
    res = upload_file(crop_path, {remove_source: true})
    CamaleonCms::User.find(params[:saved_avatar]).set_meta('avatar', res["url"]) if params[:saved_avatar].present? # save current crop image as avatar
    render text: res["url"]
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
    @tree = cama_uploader.search(params[:search]) if params[:search].present?
    if params[:partial].present?
      render partial: "files_list", locals: { files: @tree[:files], folders: @tree[:folders] }
    end
    render "index", layout: false unless params[:partial].present?
  end

  # do background actions in fog
  def actions
    if params[:media_action] != 'crop_url'
      authorize! :manage, :media
    end
    params[:folder] = params[:folder].gsub("//", "/") if params[:folder].present?
    case params[:media_action]
      when "new_folder"
        render partial: "render_folder_item", locals: { fname: params[:folder].split("/").last, folder: cama_uploader.add_folder(params[:folder])}
      when "del_folder"
        cama_uploader.delete_folder(params[:folder])
        render inline: ""
      when "del_file"
        cama_uploader.delete_file(params[:folder].gsub("//", "/"))
        render inline: ""
      when 'crop_url'
        r = cama_tmp_upload(params[:url], formats: params[:formats])
        unless r[:error].present?
          params[:file_upload] = r[:file_path]
          upload({remove_source: true})
        else
          render inline: r[:error]
        end
    end
  end

  # upload files from media uploader
  def upload(settings = {})
    f = {error: "File not found."}
    if params[:file_upload].present?
      f = upload_file(params[:file_upload], {folder: params[:folder], dimension: params['dimension'], formats: params[:formats], versions: params[:versions], thumb_size: params[:thumb_size]}.merge(settings))
    end

    render(partial: "render_file_item", locals:{ file: f }) unless f[:error].present?
    render inline: f[:error] if f[:error].present?
  end

  private
  # init basic media variables
  def init_media_vars
    @cama_uploader = CamaleonCmsLocalUploader.new({current_site: current_site, private: true}) if params[:private].present?
    cama_uploader.clear_cache if params[:cama_media_reload].present? && params[:cama_media_reload] == 'clear_cache'
    @media_formats = (params[:media_formats] || "").sub("media", ",video,audio").sub("all", "").split(",")
    @tree = cama_uploader.objects(@folder = params[:folder] || "/")
    @show_file_actions ||= params[:actions].to_s == 'true'
  end

end
