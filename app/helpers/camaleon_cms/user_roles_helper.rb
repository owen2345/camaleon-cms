#encoding: utf-8
module CamaleonCms::UserRolesHelper
  def cama_get_roles_values
    @_cache_cama_get_roles_values ||= lambda{
      roles_list = CamaleonCms::UserRole::ROLES
      # permit to add custom roles to be listed in editing roles form
      # sample: args[:roles_list][:manager] << { key: 'my_role_key', label: "my_custom_permission", description: "lorem ipsum"}
      # authorize! :manage, :my_role_key
      args = {roles_list: roles_list}; hooks_run("available_user_roles_list", args)
      args[:roles_list]
    }.call
  end
end
