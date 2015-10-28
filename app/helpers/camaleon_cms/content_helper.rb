=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module CamaleonCms::ContentHelper
  # initialize content variables
  def cama_content_init
    @_before_content = []
    @_after_content = []
  end

  # prepend content for admin or frontend (after <body>)
  # sample: cama_content_prepend(<div>my prepend content</div>)
  def cama_content_prepend(content)
    @_before_content << content
  end

  # append content for admin or frontend (before </body>)
  # sample: cama_content_prepend(<div>my after content</div>)
  def cama_content_append(content)
    @_after_content << content
  end

  # draw all before contents registered by cama_content_prepend
  def cama_content_before_draw
    @_before_content.join("") rescue ""
  end

  # draw all after contents registered by cama_content_append
  def cama_content_after_draw
    @_after_content.join("") rescue ""
  end
end