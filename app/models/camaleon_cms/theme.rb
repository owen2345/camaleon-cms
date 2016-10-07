class CamaleonCms::Theme < CamaleonCms::TermTaxonomy
  # attrs:
  #   slug => plugin key
  has_many :metas, -> { where(object_class: 'Theme') }, class_name: "CamaleonCms::Meta", foreign_key: :objectid, dependent: :destroy
  belongs_to :site, class_name: "CamaleonCms::Site", foreign_key: :parent_id

  default_scope { where(taxonomy: :theme) }

  before_validation :fix_name
  before_destroy :destroy_custom_fields

  # return theme settings configured in config.json
  def settings
    PluginRoutes.theme_info(self.slug)
  end

  # return the path to the settings file for current theme
  def settings_file
    File.join(self.settings["path"], "views/admin/settings.html.erb").to_s
  end

  private
  def fix_name
    self.name = self.slug unless self.name.present?
  end

  def destroy_custom_fields
    self.get_field_groups.destroy_all
  end

end
