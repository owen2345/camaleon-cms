module CamaleonCms
  class Meta < CamaleonRecord
    self.table_name = "#{PluginRoutes.static_system_info['db_prefix']}metas"
    # attr_accessible :objectid, :key, :value, :object_class

    belongs_to :owner, polymorphic: true, foreign_key: :objectid, foreign_type: :object_class, optional: true

    extend CamaleonCms::NormalizeAttrs
  end
end
