module CamaleonCms
  class Meta < ApplicationRecord
    self.table_name = "#{PluginRoutes.static_system_info['db_prefix']}metas"
    # attr_accessible :objectid, :key, :value, :object_class
  end
end
