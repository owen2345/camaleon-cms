=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module CamaleonCms::Admin::BreadcrumbHelper
  # draw the title for the admin admin panel according the breadcrumb
  def cama_admin_title_draw
    res = [t("camaleon_cms.admin.sidebar_top.admin_panel")]
    @breadcrumbs.reverse.slice(0, 2).reverse.each{|b| res << b.name }
    res.join(" &raquo; ")
  end

  # add breadcrumb item at the end
  # label => label of the link
  # url: url for the link
  # DEPRECATED
  def admin_breadcrumb_add(label, url = "")
  end
end