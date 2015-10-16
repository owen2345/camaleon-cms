=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module CamaleonCms::Admin::BreadcrumbHelper
# draw html admin breadcrumb
  def admin_breadcrumb_draw
    res = []
    @_admin_breadcrumb.each_with_index do |item, index|
      if @_admin_breadcrumb.size == (index+1) #last menu
        res << "<li class='active'>#{item[0]}</li>"
      else
        res << "<li><a href='#{item[1]}'>#{item[0]}</a></li>"
      end
    end
    res.join("")
  end

  def admin_title_draw
    res = []
    @_admin_breadcrumb.each_with_index do |item, index|
      res << item[0]
    end
    res.join(" &raquo; ")
  end

  # add breadcrumb item at the end
  # label => label of the link
  # url: url for the link
  def admin_breadcrumb_add(label, url = "")
    @_admin_breadcrumb << [label, url]
  end
end