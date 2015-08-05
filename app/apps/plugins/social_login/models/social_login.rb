=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::SocialLogin::Models::SocialLogin < ActiveRecord::Base
  # here create your models normally
  # notice: your tables in database will be plugins_social_login in plural (check rails documentation)
  attr_accessible :provider, :uid, :content, :user_id, :site_id
  belongs_to :user, class_name: "User", foreign_key: :user_id
  belongs_to :site, class_name: "Site", foreign_key: :site_id

end
