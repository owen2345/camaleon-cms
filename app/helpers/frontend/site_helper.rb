=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module Frontend::SiteHelper
  # return full current visited url
  def site_current_url
    request.original_url
  end

  # return current url visited as path
  # http://localhost:9001/category/cat-post-2  => /category/cat-post-2
  def site_current_path
    @_site_current_path ||= site_current_url.sub(root_url(locale: nil), "/")
  end

  #**************** section is a? ****************#
  def is_home?
    params[:controller] == "frontend" && params[:action] == "index"
  end

  def is_page?
    params[:controller] == "frontend" && params[:action] == "post"
  end

  def is_ajax?
    params[:controller] == "frontend" && params[:action] == "ajax"
  end

  def is_search?
    params[:controller] == "frontend" && params[:action] == "search"
  end

  def is_post_type?
    params[:controller] == "frontend" && params[:action] == "post_type"
  end

  def is_post_tag?
    params[:controller] == "frontend" && params[:action] == "post_tag"
  end

  def is_category?
    params[:controller] == "frontend" && params[:action] == "category"
  end
  #**************** end section is a? ****************#

  # show custom assets added by plugins
  # show respond js and html5shiv
  def the_head(seo = true)
    icon = "<link rel='shortcut icon' href='#{current_site.the_icon}'>"
    js = "<script>var ROOT_URL = '#{root_url}'; var LANGUAGE = '#{I18n.locale}'; </script>"
    icon + "\n" + csrf_meta_tag + "\n" + (seo ? display_meta_tags(the_seo) : "") + "\n" + js + "\n" + draw_custom_assets
  end
end
