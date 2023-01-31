module CamaleonCms
  class Theme < CamaleonCms::TermTaxonomy
    include CamaleonCms::CustomFields

    # attrs:
    #   slug => plugin key
    belongs_to :site, class_name: "CamaleonCms::Site", foreign_key: :parent_id, required: false
    before_validation :fix_name

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
  end
end
