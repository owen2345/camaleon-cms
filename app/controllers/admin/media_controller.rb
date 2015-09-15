=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Admin::MediaController < AdminController
  include ElFinder::Action
  skip_before_filter :authenticate, only: :img
  skip_before_filter :admin_logged_actions, except: :index
  skip_before_filter :verify_authenticity_token

  def index
    authorize! :manager, :media
  end

  def elfinder
    dirname =  "/media/#{current_site.id}"
    r = {dirname: dirname}; hooks_run("elfinder", r)
    dirname = r[:dirname]
    dir = File.join(Rails.public_path, dirname)
    FileUtils.mkdir_p(dir) unless File.directory?(dir)
    h, r = ElFinder::Connector.new(
        :mime_handler => ElFinder::MimeType,
        :root => dir,
        :url => dirname,
        :thumbs => true,
        :thumbs_size => 100,
        :thumbs_directory => 'thumbs',
        :home => t("admin.media.home"),
        :original_filename_method => lambda { |file| "#{File.basename(file.original_filename,File.extname(file.original_filename)).parameterize}#{File.extname(file.original_filename)}" },
        :default_perms => { :read => true, :write => true, :rm => true, :hidden => false },
    ).run(params)

    headers.merge!(h)

    render (r.empty? ? {:nothing => true} : {:text => r.to_json}), :layout => false
  end

  def iframe
    render layout: false
  end

  def crop
    url_image = crop_image(params[:cp_img_path], params[:ic_w], params[:ic_h], params[:ic_x], params[:ic_y])
    if params[:saved_avatar].present?
      User.find(params[:saved_avatar]).set_meta('avatar', url_image)
    end
    render text: url_image
  end
end
