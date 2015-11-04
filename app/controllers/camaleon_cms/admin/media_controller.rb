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
  skip_before_filter :verify_authenticity_token

  def index
    authorize! :manager, :media
    add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.media")
  end

  def iframe
    render layout: false
  end

  def crop
    url_image = cama_crop_image(params[:cp_img_path], params[:ic_w], params[:ic_h], params[:ic_x], params[:ic_y])
    if params[:saved_avatar].present?
      CamaleonCms::User.find(params[:saved_avatar]).set_meta('avatar', url_image)
    end
    render text: url_image
  end
end
