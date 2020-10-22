module CamaleonCms
  class Theme < CamaleonCms::TermTaxonomy
    # attrs:
    #   slug => plugin key
    cama_define_common_relationships('Theme')
    belongs_to :site, class_name: "CamaleonCms::Site", foreign_key: :parent_id

    default_scope { where(taxonomy: :theme) }

    before_validation :fix_name
    before_destroy :destroy_custom_fields

    # return theme settings configured in config.json
    def settings
      PluginRoutes.theme_info(slug)
    end

    # return the path to the settings file for current theme
    def settings_file
      File.join(self.settings["path"], "views/admin/settings").to_s
    end

    private
    def fix_name
      self.name = slug if name.blank?
    end

    def destroy_custom_fields
      get_field_groups.destroy_all
    end
  end
end
