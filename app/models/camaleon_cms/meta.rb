module CamaleonCms
  class Meta < ActiveRecord::Base
    self.table_name = "#{PluginRoutes.static_system_info["db_prefix"]}metas"
    belongs_to :record, polymorphic: true

    def self.parse_value(value)
      value = PluginRoutes.fixActionParameter(value || {})
      value = value.cama_to_var if value.is_a?(String)
      value = value.to_json if value.is_a?(Array) || value.is_a?(Hash)
      value
    end
  end
end
