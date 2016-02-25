=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::Admin::MediaController < CamaleonCms::AdminController
  skip_before_filter :cama_authenticate, only: :img
  skip_before_filter :admin_logged_actions, except: :index
  skip_before_filter :verify_authenticity_token, only: :upload
  before_action :init_media_vars

  # render media section
  def index
    authorize! :manager, :media
    @show_file_actions = true
    add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.media")
  end

  # crop a image to save as a new file
  def crop
    path_image = Rails.root.join("tmp", File.basename(params[:cp_img_path])).to_s
    if current_site.get_option("filesystem_type", "local") == "local"
      FileUtils.cp(Rails.root.join("public", "media", params[:cp_img_path].scan(/\/media\/(.*)/).first.first).to_s, path_image)
    else
      File.open(path_image, 'wb'){ |fo| fo.write(open(params[:cp_img_path]).read) }
    end
    crop_path = cama_crop_image(path_image, params[:ic_w], params[:ic_h], params[:ic_x], params[:ic_y])
    res = upload_file(crop_path, {remove_source: true})
    if params[:saved_avatar].present?
      CamaleonCms::User.find(params[:saved_avatar]).set_meta('avatar', res["url"])
    end
    render text: res["url"]
  end

  # render media for modal content
  def ajax
    @show_file_actions = true
    render partial: "files_list" if params[:partial].present?
    render "index", layout: false unless params[:partial].present?
  end

  # do background actions in fog
  def actions
    authorize! :manager, :media
    params[:folder] = params[:folder].gsub("//", "/") if params[:folder].present?
    case params[:media_action]
      when "new_folder"
        cama_uploader_add_folder(params[:folder])
        render partial: "render_folder_item", locals: { fname: params[:folder].split("/").last}
      when "del_folder"
        cama_uploader_destroy_folder(params[:folder])
        render inline: ""
      when "del_file"
        cama_uploader_destroy_file(params[:folder].gsub("//", "/"))
        render inline: ""
      when 'crop_url'
        params[:url] = Rails.public_path.join(params[:url].sub(current_site.the_url, '')).to_s if params[:url].include?(current_site.the_url) # local file
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
      f = upload_file(params[:file_upload], {folder: params[:folder], dimension: params['dimension'], formats: params[:formats]}.merge(settings))
    end

    render(partial: "render_file_item", locals:{ file: f }) unless f[:error].present?
    render inline: f[:error] if f[:error].present?
  end

  private
  # init basic media variables
  def init_media_vars
    @media_formats = (params[:media_formats] || "").sub("media", ",video,audio").sub("all", "").split(",")
    @folder = params[:folder] || "/"
    @tree = cama_media_find_folder(@folder)
    @show_file_actions ||= params[:actions].to_s == 'true'
  end

end
