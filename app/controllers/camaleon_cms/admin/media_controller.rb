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

  # render media section
  def index
    authorize! :manager, :media
    add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.media")
    init_media_vars
  end

  def crop
    url_image = cama_crop_image(params[:cp_img_path], params[:ic_w], params[:ic_h], params[:ic_x], params[:ic_y])
    if params[:saved_avatar].present?
      CamaleonCms::User.find(params[:saved_avatar]).set_meta('avatar', url_image)
    end
    render text: url_image
  end

  # render media for modal content
  def ajax
    init_media_vars
    render partial: "files_list" if params[:partial].present?
    render "index", layout: false unless params[:partial].present?
  end

  # upload files from media uploader
  def upload
    f = {error: "File not found."}
    if params[:file_upload].present?
      f = upload_file(params[:file_upload], {folder: params[:folder]})
    end

    unless f[:error].present?
      render partial: "render_file_item", locals:{ file: f }
    else
      render inlien: f[:error]
    end
  end

  private
  # init basic media variables
  def init_media_vars
    @media_formats = (params[:media_formats] || "").split(",")
    @folder = params[:folder] || "/"
    @tree = cama_media_find_folder(@folder)
  end

end
