=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
#encoding: utf-8
module CamaleonCms::UserRolesHelper
  def cama_get_roles_values
    roles_list = CamaleonCms::UserRole::ROLES
    # permit to add custom roles to be listed in editing roles form
    # sample: args[:roles_list][:manager] << { key: 'my_role_key', label: "my_custom_permission", description: "lorem ipsum"}
    # authorize! :manage, :my_role_key
    args = {roles_list: roles_list}; hooks_run("available_user_roles_list", args)
    args[:roles_list]
  end
end