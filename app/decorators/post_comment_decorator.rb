=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class PostCommentDecorator < Draper::Decorator
  delegate_all

  # return created at date formatted
  def the_created_at(format = :long)
    h.l(object.created_at, format: format.to_sym)
  end

  # return owner of this comment
  def the_user
    object.user
  end

  def the_content
    object.content
  end
end
